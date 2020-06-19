Rails.application.config.after_initialize do

  ApplicationHelper.class_eval do

    alias_method :render_aspace_partial_pre_editable_external_ids, :render_aspace_partial
    def render_aspace_partial(args)

      if args[:partial] == "external_ids/edit" && show_external_ids? && user_can?("administer_system")
        return render :partial => "shared/subrecord_form", :locals => {:form => args[:locals][:form], :name => "external_ids"}
      end

      render_aspace_partial_pre_editable_external_ids(args);
    end
  end

  SidebarHelper::SidebarGenerator.class_eval do
    alias_method :show_external_ids_sidebar_entry_pre_editable_external_ids, :show_external_ids_sidebar_entry?
    def show_external_ids_sidebar_entry?
      show_external_ids_sidebar_entry_pre_editable_external_ids ||
        (@form.controller.action_name != 'show' && @form.controller.class.session_can?(@form.controller, "administer_system"))
    end
  end

end