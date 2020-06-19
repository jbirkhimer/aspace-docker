module ASpaceExport
  # Convenience methods that will work for resource
  # or archival_object models during serialization
  module ArchivalObjectDescriptionHelpers

    
    def controlaccess_subjects
      unless @controlaccess_subjects
        results = []
        linked = self.subjects || []
        linked.each do |link|
          subject = link['_resolved']

          node_name = case subject['terms'][0]['term_type']
                      when 'function'; 'function'
                      when 'genre_form', 'style_period';  'genreform'
                      when 'geographic'; 'geogname'
                      when 'occupation';  'occupation'
                      when 'topical', 'temporal','cultural_context'; 'subject'
                      when 'uniform_title'; 'title'
                      else; nil
                      end

          next unless node_name

          content = subject['terms'].map{|t| t['term']}.join(' -- ')

          atts = {}
          atts['source'] = subject['source'] if subject['source']
          atts['authfilenumber'] = subject['authority_id'] if subject['authority_id']
          atts['altrender'] = subject['terms'][0]['term_type'] if subject['terms'][0]['term_type']

          results << {:node_name => node_name, :atts => atts, :content => content}
        end

        @controlaccess_subjects = results
      end

      @controlaccess_subjects
    end

  end
end
