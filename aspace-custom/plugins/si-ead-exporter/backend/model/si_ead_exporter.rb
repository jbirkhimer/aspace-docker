# encoding: utf-8
require 'nokogiri'
require 'securerandom'


class EADSerializer < ASpaceExport::Serializer
    serializer_for :ead

    # MODIFCATION: Add @type for EDAN object_type processing
    def serialize_extents(obj, xml, fragments)
      if obj.extents.length
        obj.extents.each do |e|
          next if e["publish"] === false && !@include_unpublished
          audatt = e["publish"] === false ? {:audience => 'internal'} : {}

          extent_number_float = e['number'].to_f
          extent_type = I18n.t('enumerations.extent_extent_type.'+e['extent_type'], :default => e['extent_type'])
          #if extent_number_float == 1.0
          #  extent_type = SingularizeExtents.singularize_extent(extent_type)
          #end

          xml.physdesc({:altrender => e['portion']}.merge(audatt)) {
            if e['number'] && e['extent_type'] 
              xml.extent({:type => extent_type}) {
                sanitize_mixed_content("#{e['number']} #{extent_type}", xml, fragments)
              }
            end
            if e['container_summary']
              xml.extent({:altrender => 'carrier'}) {
                sanitize_mixed_content( e['container_summary'], xml, fragments)
              }
            end
            xml.physfacet { sanitize_mixed_content(e['physical_details'],xml, fragments) } if e['physical_details']
            xml.dimensions  {   sanitize_mixed_content(e['dimensions'],xml, fragments) }  if e['dimensions']
          }
        end
      end
    end

    
    def serialize_controlaccess(data, xml, fragments)
    if (data.controlaccess_subjects.length + data.controlaccess_linked_agents.length) > 0
      xml.controlaccess {

        data.controlaccess_subjects.each do |node_data|
          xml.send(node_data[:node_name], node_data[:atts]) {
            sanitize_mixed_content( node_data[:content], xml, fragments, ASpaceExport::Utils.include_p?(node_data[:node_name]) )
          }
        end


        data.controlaccess_linked_agents.each do |node_data|
          xml.send(node_data[:node_name], node_data[:atts]) {
            sanitize_mixed_content( node_data[:content], xml, fragments,ASpaceExport::Utils.include_p?(node_data[:node_name]) )
          }
        end

      } #</controlaccess>
    end
  end

    

end

