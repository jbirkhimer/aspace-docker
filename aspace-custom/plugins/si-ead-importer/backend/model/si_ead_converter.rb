class SIEADConverter < EADConverter

  def self.import_types(show_hidden = false)
    [
     {
       :name => "si_ead_xml",
       :description => "Import SI EAD records from an XML file"
     }
    ]
  end


  def self.instance_for(type, input_file)
    if type == "si_ead_xml"
      self.new(input_file)
    else
      nil
    end
  end

  def format_content(content)
    super.gsub(/[, ]+$/,"") # Remove trailing commas and spaces
  end

  def self.configure
    super



    
# BEGIN CHRONLIST CUSTOMIZATIONS
# Verified 2018-02-20
# Separate <chronlist>s out of notes like it does with <list>s (Do not repeat the chronlist in the paragraph block)
# The addition of (split_tag = 'chronlist') to the insert_into_subnotes method call here fixes that
    with 'chronlist' do |*|
      if  ancestor(:note_multipart)
        left_overs = insert_into_subnotes(split_tag = 'chronlist')
      else 
        left_overs = nil 
        make :note_multipart, {
          :type => node.name,
          :persistent_id => att('id'),
        } do |note|
          set ancestor(:resource, :archival_object), :notes, note
        end
      end
      
      make :note_chronology do |note|
        set ancestor(:note_multipart), :subnotes, note
      end
      
      # and finally put the leftovers back in the list of subnotes...
      if ( !left_overs.nil? && left_overs["content"] && left_overs["content"].length > 0 ) 
        set ancestor(:note_multipart), :subnotes, left_overs 
      end 
    end

# END CHRONLIST CUSTOMIZATIONS

    
# BEGIN CUSTOM AGENT IMPORTS
# Verified 2018-02-20
# Custom import will allow EAD to include a ref attribute, linking directly to the URI for pre-existing access point.
# This will check our EADs for a ref attribute for corpname, famname, and persname elements  (consider also a subject, geogname, genreform)
# If a ref attribute is present, it will use that to link the agent to the resource.
# If there is no ref attribute, it will make a new agent as usual.

    with 'origination/corpname' do |*|
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'creator', 'relator' => relator}
        else
            make_corp_template(:role => 'creator', :relator => relator)
        end
    end

    with 'controlaccess/corpname' do |*|
        corpname = Nokogiri::XML::DocumentFragment.parse(inner_xml)
        terms ||= []
        corpname.children.each do |child|
            if child.respond_to?(:name) && child.name == 'term'
                term = child.content.strip
                term_type = child['type']
                terms << {'term' => term, 'term_type' => term_type, 'vocabulary' => '/vocabularies/1'}
            end
        end
        
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'subject', 'terms' => terms, 'relator' => relator}
        else
            make_corp_template(:role => 'subject', :relator => relator)
        end
    end

    with 'origination/famname' do |*|
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'creator', 'relator' => relator}
        else
            make_family_template(:role => 'creator', :relator => relator)
        end
    end

    with 'controlaccess/famname' do |*|
        famname = Nokogiri::XML::DocumentFragment.parse(inner_xml)
        terms ||= []
        famname.children.each do |child|
            if child.respond_to?(:name) && child.name == 'term'
                term = child.content.strip
                term_type = child['type']
                terms << {'term' => term, 'term_type' => term_type, 'vocabulary' => '/vocabularies/1'}
            end
        end
        
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'subject', 'terms' => terms, 'relator' => relator}
        else
            make_family_template(:role => 'subject', :relator => relator)
        end
    end

    with 'origination/persname' do |*|
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'creator', 'relator' => relator}
        else
            make_person_template(:role => 'creator', :relator => relator)
        end
    end

    with 'controlaccess/persname' do |*|
        persname = Nokogiri::XML::DocumentFragment.parse(inner_xml)
        terms ||= []
        persname.children.each do |child|
            if child.respond_to?(:name) && child.name == 'term'
                term = child.content.strip
                term_type = child['type']
                terms << {'term' => term, 'term_type' => term_type, 'vocabulary' => '/vocabularies/1'}
            end
        end
        
        if att('role')
            relator = att('role')
        else
            relator = nil
        end
        
        if att('ref')
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => att('ref'), 'role' => 'subject', 'terms' => terms, 'relator' => relator}
        else
            make_person_template(:role => 'subject', :relator => relator)
        end
    end

# END CUSTOM AGENT IMPORTS

# BEGIN TEMPLATE ADJUST FOR AGENTS
# Authority ID import verified 2018-02-20
# These will allow a relator term via opts[] for linking the new agent to a resource.
# Stock importer called the authority_id via att('id').  Changed here to call att('authfilenumber') from the EAD 

    def make_corp_template(opts)
        return nil if inner_xml.strip.empty?
        make :agent_corporate_entity, {
            :agent_type => 'agent_corporate_entity'
        } do |corp|
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => corp.uri, 'role' => opts[:role], 'relator' => opts[:relator]}
        end
        
        make :name_corporate_entity, {
            :primary_name => inner_xml,
            :rules => att('rules'),
            :authority_id => att('authfilenumber'),
            :source => att('source') || 'ingest'
        } do |name|
            set ancestor(:agent_corporate_entity), :names, proxy
        end
    end


    def make_family_template(opts)
        return nil if inner_xml.strip.empty?
        make :agent_family, {
            :agent_type => 'agent_family',
        } do |family|
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => family.uri, 'role' => opts[:role], 'relator' => opts[:relator]}
        end
        
        make :name_family, {
            :family_name => inner_xml,
            :rules => att('rules'),
            :authority_id => att('authfilenumber'),
            :source => att('source') || 'ingest'
        } do |name|
            set ancestor(:agent_family), :names, name
        end
    end


    def make_person_template(opts)
        return nil if inner_xml.strip.empty?
        make :agent_person, {
            :agent_type => 'agent_person',
        } do |person|
            set ancestor(:resource, :archival_object), :linked_agents, {'ref' => person.uri, 'role' => opts[:role], 'relator' => opts[:relator]}
        end
        
        make :name_person, {
            :name_order => 'inverted',
            :primary_name => inner_xml,
            :authority_id => att('authfilenumber'),
            :rules => att('rules'),
            :source => att('source') || 'ingest'
        } do |name|
            set ancestor(:agent_person), :names, name
        end
    end
# END TEMPLATE ADJUST FOR AGENTS


# BEGIN CUSTOM SUBJECT IMPORTS 
# Verified - 2018-02-20, functional, geog, occupation, subject, title each import successfully.  I fsubject has latrender 'cultural_context' will import the 695 culture terms.
# For compound agents, import sub-terms correctly (agents with subdivided subject terms)
# In ArchivesSpace, this kind of agent can be represented in a resource by linking to the agent and adding terms/subdivisions within the resource.
# We could accomplish this by invalidating our EAD at some point (gasp!) to add <term> tags around the individual terms in a corpname, persname, or famname. 
# This modification would also make sure that those terms get imported properly.

    {
      'function' => 'function',
      'genreform' => 'genre_form',
      'geogname' => 'geographic',
      'occupation' => 'occupation',
      #'subject' => 'topical',
      'culture' => 'cultural_context',
      'title' => 'uniform_title' # added title since we have some <title> tags in our controlaccess
      }.each do |tag, type|
        with "controlaccess/#{tag}" do |*|
          if att('ref')
            set ancestor(:resource, :archival_object), :subjects, {'ref' => att('ref')}
          else
            make :subject, {
                :terms => {'term' => inner_xml, 'term_type' => type, 'vocabulary' => '/vocabularies/1'},
                :vocabulary => '/vocabularies/1',
                :source => att('source') || 'ingest'
              } do |subject|
                set ancestor(:resource, :archival_object), :subjects, {'ref' => subject.uri}
                end
           end
        end
     end
     
     with 'controlaccess/subject' do |*|
          if att('ref')
            set ancestor(:resource, :archival_object), :subjects, {'ref' => att('ref')}
          elsif att('altrender')
            make :subject, {
                :terms => {'term' => inner_xml, 'term_type' => att('altrender'), 'vocabulary' => '/vocabularies/1'},
                :vocabulary => '/vocabularies/1',
                :source => att('source') || 'ingest'
              } do |subject|
                set ancestor(:resource, :archival_object), :subjects, {'ref' => subject.uri}
                end
          else
            make :subject, {
                :terms => {'term' => inner_xml, 'term_type' => 'topical', 'vocabulary' => '/vocabularies/1'},
                :vocabulary => '/vocabularies/1',
                :source => att('source') || 'ingest'
              } do |subject|
                set ancestor(:resource, :archival_object), :subjects, {'ref' => subject.uri}
                end
           end
        end
# END CUSTOM SUBJECT IMPORTS 


# BEGIN CLASSIFICATION CUSTOMIZATIONS
# In ArchivesSpace, we may begin using Classifications to distinguish major collecting areas or sub-divided record groups.
# This modification will link the resource being created to the appropriate Classification in ArchivesSpace

  with 'archref' do |*|
    set :classifications, {'ref' => att('altrender')}
  end

# END CLASSIFICATION CUSTOMIZATIONS


# BEGIN DAO TITLE CUSTOMIZATIONS
# Verified - 2018-02-20, title added from parent, caption does not import.
# Stock EAD importer requires DO @title. Also, EAD with long @title will fail, when trying to also copy to file version caption.
# This custom version will set DO's title to the parent archival object's title (and/or date, if exists)
# This custom version will not also create file version caption
# This custom version will also allow DO ID to be set on import (or fallback to secure random)


# consider also supporting make-representative...

with 'dao' do |x|

  if att('ref') # A digital object has already been made
    make :instance, {
      :instance_type => 'digital_object',
      :digital_object => {'ref' => att('ref')}
       } do |instance|
    set ancestor(:resource, :archival_object), :instances, instance
    end
  else # Make a digital object
    make :instance, {
      :instance_type => 'digital_object'
      } do |instance|
    set ancestor(:resource, :archival_object), :instances, instance
    end
    # We'll use either the <dao> title attribute (if it exists) or our display_string (if the title attribute does not exist)
    # This forms a title string using the parent archival object's title, if it exists
    daotitle = nil
    ancestor(:archival_object ) do |ao|
      if ao.title && ao.title.length > 0
        daotitle = ao.title
      end
    end

    # This forms a date string using the parent archival object's date expression,
    # just string the dates together for simplicity
    daodates = []
    daodate_type = nil
    daodate_label = nil
    ancestor(:archival_object) do |aod|
      if aod.dates && aod.dates.length > 0
        aod.dates.each do |dl|
          if dl['expression'].length > 0
            daodates << dl['expression']
            daodate_type = dl['date_type']
            daodate_label = dl['label']
          end
        end
      end
    end

    title = daotitle
    date_label = daodates.join(', ') if daodates.length > 0

    # This forms a display string using the parent archival object's title and date (if both exist),
    # or just its title or date (if only one exists)
    display_string = title || ''
    #display_string += ', ' if title && date_label
    #display_string += date_label if date_label

    make :digital_object, {
      :digital_object_id => att('id') || SecureRandom.uuid,
      :title => att('title') || display_string
      } do |obj|
        obj.file_versions <<  {
        :use_statement => att('role'),
        :file_uri => att('href'),
        :xlink_actuate_attribute => att('actuate'),
        :xlink_show_attribute => att('show')
        }
        if date_label
            obj.dates <<  {
            :expression => date_label,
            :date_type => 'inclusive',
            :label => daodate_label
            }
        end
      set ancestor(:instance), :digital_object, obj
      end
    end
  end
end

    with 'daodesc' do |*|

        ancestor(:digital_object) do |dobj|
          next if dobj.ref
        end
        
        make :note_digital_object, {
          :type => 'note',
          :persistent_id => att('id'),
          :content => modified_format_content(inner_xml.strip,'daodesc')
        } do |note|
          set ancestor(:digital_object), :notes, note
        end
    end

# END DAO TITLE CUSTOMIZATIONS





=begin
# Note: The following bits are here for historical reasons
# We have either decided against implementing the functionality OR the ArchivesSpace importer has changed, deprecating the following customizations

# BEGIN LANGUAGE CUSTOMIZATIONS
# By default, ASpace now uses the first <language> tag it finds as the primary language of the material described. 
# And, strips the tagged language names. Consider allow tagging? Otherwise don't need this

with "langmaterial" do |*|
  # first, assign the primary language to the ead
  langmaterial = Nokogiri::XML::DocumentFragment.parse(inner_xml)
  langmaterial.children.each do |child|
    if child.name == 'language'
      set ancestor(:resource, :archival_object), :language, child.attr("langcode")
      break
    end
  end

  # write full tag content to a note, subbing out the language tags
  content = inner_xml
  next if content =~ /\A<language langcode=\"[a-z]+\"\/>\Z/

  if content.match(/\A<language langcode=\"[a-z]+\"\s*>([^<]+)<\/language>\Z/)
    content = $1
  end

  make :note_singlepart, {
    :type => "langmaterial",
    :persistent_id => att('id'),
    :publish => true,
    :content => format_content( content.sub(/<head>.*?<\/head>/, '') )
  } do |note|
    set ancestor(:resource, :archival_object), :notes, note
  end
end

# overwrite the default language tag behavior
with "language" do |*|
  next
end

# END LANGUAGE CUSTOMIZATIONS




=end

end
