# plugins/local/frontend/models/search_result_data.rb
# provides translations and redefines facets, which you can see at:
# https://github.com/archivesspace/archivesspace/blob/master/frontend/app/models/search_result_data.rb#L215-L257


require Rails.root.join('app/models/search_result_data')

class SearchResultData

# 2017-10-01 SMITHSONIAN customization: this changes what facets are requested for Accessions, Resources, DO, Subjects, Location . 
# Display order follows the order in the array. 

# 2018-10-25 SMITHSONIAN customization: translation for finding aid status, acq type

  def facet_label_string(facet_group, facet)
    return I18n.t("#{facet}._singular", :default => I18n.t("plugins.#{facet}._singular", :default => facet)) if facet_group === "primary_type"
    return I18n.t("enumerations.name_source.#{facet}", :default => I18n.t("enumerations.subject_source.#{facet}", :default => facet)) if facet_group === "source"
    return I18n.t("enumerations.name_rule.#{facet}", :default => facet) if facet_group === "rules"
    return I18n.t("boolean.#{facet.to_s}", :default => facet) if facet_group === "publish"
    return I18n.t("enumerations.digital_object_digital_object_type.#{facet.to_s}", :default => facet) if facet_group === "digital_object_type"
    return I18n.t("enumerations.location_temporary.#{facet.to_s}", :default => facet) if facet_group === "temporary"
    return I18n.t("enumerations.event_event_type.#{facet.to_s}", :default => facet) if facet_group === "event_type"
    return I18n.t("enumerations.event_outcome.#{facet.to_s}", :default => facet) if facet_group === "outcome"
    return I18n.t("enumerations.subject_term_type.#{facet.to_s}", :default => facet) if facet_group === "first_term_type"
    
    return I18n.t("enumerations.resource_finding_aid_status.#{facet}", :default => I18n.t("enumerations.resource_finding_aid_status.#{facet}", :default => facet)) if facet_group === "finding_aid_status"
    return I18n.t("enumerations.accession_acquisition_type.#{facet}", :default => I18n.t("enumerations.accession_acquisition_type.#{facet}", :default => facet)) if facet_group === "acquisition_type"
    

    if facet_group === "source"
      if single_type? and types[0] === "subject"
        return I18n.t("enumerations.subject_source.#{facet}", :default => facet)
      else
        return I18n.t("enumerations.name_source.#{facet}", :default => facet)
      end
    end

    if facet_group === "level"
        if single_type? and types[0] === "digital_object"
          return I18n.t("enumerations.digital_object_level.#{facet.to_s}", :default => facet)
        else
          return I18n.t("enumerations.archival_record_level.#{facet.to_s}", :default => facet)
        end
    end

    # labels for collection management groups
    return I18n.t("#{facet}._singular", :default => facet) if facet_group === "parent_type"
    return I18n.t("enumerations.collection_management_processing_priority.#{facet}", :default => facet) if facet_group === "processing_priority"
    return I18n.t("enumerations.collection_management_processing_status.#{facet}", :default => facet) if facet_group === "processing_status"

    if facet_group === "classification_path"
      return ClassificationHelper.format_classification(ASUtils.json_parse(facet))
    end

    if facet_group === "assessment_review_required"
      return I18n.t("assessment._frontend.assessment_review_required.#{facet}_value")
    end

    if facet_group === "assessment_sensitive_material"
      return I18n.t("assessment._frontend.assessment_sensitive_material.#{facet}_value")
    end

    if facet_group === "assessment_inactive"
      return I18n.t("assessment._frontend.assessment_inactive.#{facet}_value")
    end

    if facet_group === "assessment_record_types"
      return I18n.t("#{facet}._singular", :default => facet)
    end

    if facet_group === "assessment_completed"
      return I18n.t("assessment._frontend.assessment_completed.#{facet}_value")
    end

    facet
  end

  def self.ACCESSION_FACETS
    ["acquisition_type", "enum_1_enum_s", "accession_date_year", "creators"]
  end
  
  def self.RESOURCE_FACETS
    [ "primary_type", "level", "finding_aid_status", "classification_path", "creators"]
  end

  def self.DIGITAL_OBJECT_FACETS
    ["publish","digital_object_type"]
  end

 def self.SUBJECT_FACETS
   ["first_term_type","source"]
 end
 
  def self.LOCATION_FACETS
    ["temporary", "building", "room", "area", "location_profile_display_string_u_ssort"]
  end
end