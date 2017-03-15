module SubmissionsHelper

  def generate_attribute_label(attr_label)
    # Get the attribute hash corresponding to the given attribute
    attr = @metadata.select{ |attr_hash| attr_hash["attribute"].to_s.eql?(attr_label) }.first

    if !attr["label"].nil?
      label_tag("submission_#{attr_label}", attr["label"])
    else
      label_tag("submission_#{attr_label}", attr_label.underscore.humanize)
    end
  end

  # Generate the HTML input for every attributes
  def generate_attribute_input(attr_label)
    input_html = ''.html_safe

    # Get the attribute hash corresponding to the given attribute
    attr = @metadata.select{ |attr_hash| attr_hash["attribute"].to_s.eql?(attr_label) }.first

    if attr["enforce"].include?("integer")
      number_field :submission, attr["attribute"].to_s.to_sym, value: @submission.send(attr["attribute"])

    elsif attr["enforce"].include?("date_time")
      if @submission.send(attr["attribute"]).nil?
        date_value = nil
      else
        date_value = DateTime.parse(@submission.send(attr["attribute"])).to_date.to_s
      end
      text_field :submission, attr["attribute"].to_s.to_sym, :class => "datepicker", value: "#{date_value}"

    elsif attr["display"].eql?("isOntology")
      # TODO: avant on concatene les ontos qui sont en dehors du site;, avec celle du site  ?
      if attr["enforce"].include?("list")
        input_html << select_tag("submission[#{attr_label}][]", options_for_select(@ontologies_for_select, @submission.send(attr["attribute"])), :multiple => 'true',
            "data-placeholder".to_sym => "Select ontologies", :style => "margin-bottom: 15px; width: 433px;", :id => "select_#{attr["attribute"]}", :class => "selectOntology")

      else
        input_html << select_tag("submission[#{attr_label}]", options_for_select(@ontologies_for_select, @submission.send(attr["attribute"])),
                   :style => "margin-bottom: 15px; width: 433px;", :id => "select_#{attr["attribute"]}", :class => "selectOntology", :include_blank => true)
      end
      # Faire un petit bouton + qui ouvre un champ texte pour ajouter une nouvelle valeur à la liste
      # Ou ajouter un element dans le DOM (dans les options)

      input_html << text_field_tag("add_#{attr["attribute"].to_s}", nil)

      input_html << button_tag("Add new value", :id => "btnAdd#{attr["attribute"]}", :style => "margin-bottom: 0.5em;margin-top: 0.5em;",
                               :type => "button", :class => "btn btn-info", :onclick => "addValueToSelect('#{attr["attribute"]}')")

      return input_html;

    elsif attr["enforce"].include?("uri")
      if @submission.send(attr["attribute"]).nil?
        uri_value = ""
      else
        uri_value = @submission.send(attr["attribute"])
      end

      if attr["enforce"].include?("list")
        input_html << url_field_tag("submission[#{attr["attribute"].to_s}][]", uri_value[0], :id => attr["attribute"].to_s, class: "metadataInput")
        # Add field if list of URI
        if !@submission.send(attr["attribute"]).nil? && @submission.send(attr["attribute"]).any?
          @submission.send(attr["attribute"]).each_with_index do |metadata_val, index|
            if index != 0
              input_html << url_field_tag("submission[#{attr["attribute"].to_s}][]", metadata_val, :id => "submission_#{attr["attribute"].to_s}", class: "metadataInput")
            end
          end
        end
        input_html << button_tag("Add new value", :id => "add#{attr["attribute"]}", :style => "margin-bottom: 0.5em;margin-top: 0.5em;",
                                 :type => "button", :class => "btn btn-info", :onclick => "addInput('#{attr["attribute"]}', 'url')")
        input_html << content_tag(:div, "", id: "#{attr["attribute"]}Div")

      else
        # if single value
        input_html << text_field(:submission, attr["attribute"].to_s.to_sym, value: uri_value, class: "metadataInput")
      end
      return input_html

    elsif attr["enforce"].include?("boolean")
      select("submission", attr["attribute"].to_s, ["none", "true", "false"], { :selected => @submission.send(attr["attribute"])},
             {:class => "form-control", :style => "margin-top: 0.5em; margin-bottom: 0.5em;"})

    else
      # If a simple text
      if attr["enforce"].include?("list")
        firstVal = ""
        if !@submission.send(attr["attribute"]).nil? && @submission.send(attr["attribute"]).any?
          firstVal = @submission.send(attr["attribute"])[0]
        end
        input_html << text_field_tag("submission[#{attr["attribute"].to_s}][]", firstVal, :id => attr["attribute"].to_s, class: "metadataInput")

        # Add field if list of metadata
        if !@submission.send(attr["attribute"]).nil? && @submission.send(attr["attribute"]).any?
          @submission.send(attr["attribute"]).each_with_index do |metadata_val, index|
            if index != 0
              input_html << text_field_tag("submission[#{attr["attribute"].to_s}][]", metadata_val, :id => "submission_#{attr["attribute"].to_s}", class: "metadataInput")
            end
          end
        end

        input_html << button_tag("Add new value", :id => "add#{attr["attribute"]}", :style => "margin-bottom: 0.5em;margin-top: 0.5em;",
                                 :type => "button", :class => "btn btn-info", :onclick => "addInput('#{attr["attribute"]}', 'text')")
        input_html << content_tag(:div, "", id: "#{attr["attribute"]}Div")

      else
        # if single value text
        # TODO: For some reason @submission.send("URI") FAILS... I don't know why... so I need to call it manually
        if attr["attribute"].to_s.eql?("URI")
          input_html << text_field(:submission, attr["attribute"].to_s.to_sym, value: @submission.URI,class: "metadataInput")
        else
          input_html << text_field(:submission, attr["attribute"].to_s.to_sym, value: @submission.send(attr["attribute"]), class: "metadataInput")
        end
      end
      return input_html
    end
  end

end