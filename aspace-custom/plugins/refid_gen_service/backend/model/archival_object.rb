require 'erb'
require 'net/http'
require 'date'
require 'digest'
require 'yaml'

# grab configuration variables from config file
config = YAML.load_file(File.join(ASUtils.find_base_directory, "plugins", "refid_gen_service", "backend", "model", "config.yaml"))
config["config"].each { |key, value| instance_variable_set("@#{key}", value) }

# call the service to generate an id number
def generate_ref_id(resourceID)
  if resourceID.empty? 
    return "missing"
  end
  
  refID = "";
  normalizedResourceID = normalize_resource_id(resourceID)
  begin
    shahex = Digest::SHA1.hexdigest @password
    url = URI.parse(@hosturl + '/numberGenerator/next?' + normalizedResourceID + '&pass=' + shahex)
    req = Net::HTTP::Get.new(url.to_s)
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    refID = res.body
  rescue
    refID = DateTime.now.strftime('%Q')
  end
  "#{resourceID}_ref#{refID}"
end

# normalize resourceID (i.e. replace punctuations, non-alphnumeric
# characters and space with an hypen)
def normalize_resource_id(resourceID)
  if resourceID.nil? || resourceID.strip.empty?
    return ""
  end

  resourceID.downcase.gsub(/[^a-z0-9]/i, '-')
end


# set the resoruce REFID to '<resource_name>_ref<generated_number>'
#rule_template = ERB.new("<%= resource['formatted_id'] %>_ref<%= generate_ref_id(resource['formatted_id']) %>")
rule_template = ERB.new("<%= generate_ref_id(resource['formatted_id']) %>")
ArchivalObject.auto_generate( :property => :ref_id,
                              :generator => proc {|json|
                                component = json
                                resource = Resource.to_jsonmodel(JSONModel::JSONModel(:resource).id_for(json['resource']['ref']))

                                # use identifier instead of ead id
                                # resource['formatted_id'] = Identifiers.parse(resource.identifier)                                
                                
                                if !resource.ead_id.nil?
                                  resource['formatted_id'] = resource.ead_id
                                else
                                  resource['formatted_id'] = ""
                                end
                                repository = Repository.to_jsonmodel(RequestContext.get(:repo_id))
                                rule_template.result(binding())
                              },
                              :only_on_create => true )
