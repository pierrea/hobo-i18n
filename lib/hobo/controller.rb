module Hobo

  module Controller

    include ControllerHelpers
    
    include AuthenticationSupport

    def self.included(base)
      if base.is_a?(Class)
        Hobo::ControllerHelpers.public_instance_methods.each {|m| base.hide_action(m)}
      end
    end


    protected

    def hobo_ajax_response(this, results={})
      part_page = params[:part_page]
      r = params[:render]
      if r
        ajax_update_response(this, part_page, r.is_a?(Array) ? r : [r], results)
        true
      else
        false
      end
    end


    def ajax_update_response(this, part_page, render_specs, results={})
      add_variables_to_assigns
      renderer = Hobo::Dryml.page_renderer(@template, [], part_page) if part_page

      render :update do |page|
        page << "var _update = typeof Hobo == 'undefined' ? Element.update : Hobo.updateElement;"
        for spec in render_specs
          function = if spec[:function]
                       spec[:function][0..0].downcase + spec[:function].camelize[1..-1]
                     else
                       "_update"
                     end

          if spec[:as] or spec[:part]
            obj = if spec[:object] == "this" or !spec[:object]
                    this
                  else
                    Hobo.object_from_dom_id(spec[:object])
                  end

            if spec[:as]
              part_content = render(:partial => (Hobo::ModelController.find_partial(obj.class, spec[:as])),
                                 :locals => { :this => obj })
              page.call(function, spec[:id], part_content)
              
            elsif spec[:part]
              dom_id = spec[:id] || spec[:part]
              part_content = renderer.call_part(dom_id, spec[:part], obj)
              page.call(function, dom_id, part_content)
            end
            
          elsif spec[:result]
            result = results[spec[:result].to_sym]
            page.call(function, spec[:id], result)
            
          else
            # spec didn't specify any action :-/
          end
        end
        if renderer
          renderer.part_contexts.each_pair do |dom_id, p|
            part_id, model_id = p
            page.assign "hoboParts.#{dom_id}", [part_id, model_id]
            
            # not sure why this isn't happending automatically
            # but it's messing up ARTS, so chuck a newline in
            page << "\n"
          end
        end
      end
    end


    def render_tag(tag, options={})
      add_variables_to_assigns
      render :text => Hobo::Dryml.render_tag(@template, tag, options)
    end


    def render_tags(objects, tag, options={})
      add_variables_to_assigns
      dryml_renderer = Hobo::Dryml.empty_page_renderer(@template)
      render :text => objects.map {|o| dryml_renderer.send(tag, options.merge(:obj => o))}.join +
                      dryml_renderer.part_contexts_js
    end


    def site_search(query)
      results = Hobo.find_by_search(query).select {|r| Hobo.can_view?(current_user, r, nil)}
      if results.empty?
        render :text => "<p>Your search returned no matches.</p>"
      else
        render_tags(results, "tag_for_object", :name => "search_result")
      end
    end


    # Store the given user in the session.
    def current_user=(new_user)
      session[:user] = (new_user.nil? || new_user.is_a?(Symbol)) ? nil : new_user.id
      @current_user = new_user
    end


    def logged_in?
      not current_user.guest?
    end


    # Check if the user is authorized.
    #
    # Override this method in your controllers if you want to restrict access
    # to only a few actions or if you want to check if the user
    # has the correct rights.
    #
    # Example:
    #
    #  # only allow nonbobs
    #  def authorize?
    #    current_user.login != "bob"
    #  end
    def authorized?
      true
    end

  end
end