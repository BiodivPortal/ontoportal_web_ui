import {Controller} from "@hotwired/stimulus"

// Connects to data-controller="form-auto-complete"
export default class extends Controller {
    static values = {
        ontologyId: String,
        targetProperty: String,
        includeDefinition: Boolean
    }

    connect() {
        if (this.ontologyIdValue === "all") {
            this.ontologyIdValue = "";
        }


        this.extra_params = {
            target_property: this.targetPropertyValue,
            id: this.ontologyIdValue
        };

        let result_width = 450;


        // Add space for ontology name
        if (this.includeDefinitionValue) {
            result_width += 200;
        }

        jQuery(this.element).bp_autocomplete(BP_INTERNAL_SEARCH_SERVER + "/search/json_search/", {
            extraParams: this.extra_params,
            lineSeparator: "~!~",
            matchSubset: 0,
            mustMatch: true,
            sortRestuls: false,
            minChars: 3,
            maxItemsToShow: 20,
            cacheLength: -1,
            width: result_width,
            onItemSelect: this.onSelect.bind(this) ,
            formatItem: this.formatItem.bind(this)
        });

        let html = "";

        const inputName = jQuery(this.element).attr('name');
        if (document.getElementById(inputName + "_bioportal_concept_id") == null)
            html += `<input type='hidden' name='${inputName}_bioportal_concept_id' id='${inputName}_bioportal_concept_id'>`;

        if (document.getElementById(inputName + "_bioportal_ontology_id") == null)
            html += `<input type='hidden' name='${inputName}_bioportal_ontology_id' id='${inputName}_bioportal_ontology_id'>`;

        if (document.getElementById(inputName + "_bioportal_full_id") == null)
            html += `<input type='hidden' name='${inputName}_bioportal_full_id' id='${inputName}_bioportal_full_id'>`;

        if (document.getElementById(inputName + "_bioportal_preferred_name") == null)
            html += `<input type='hidden' name='${inputName}_bioportal_preferred_name' id='${inputName}_bioportal_preferred_name'>`;

        jQuery(this.element).after(html);
    }

    formatItem(row) {

        const input = this.element;
        const specials = /[.*+?|()\[\]{}\\]/g;
        const keywords = jQuery(input).val().replace(specials, "\\$&").split(' ').join('|');
        const regex = new RegExp('(' + keywords + ')', 'gi');
        let result = "";
        const ontology_id = this.ontologyIdValue;
        let class_name_width = "350px";

        const BP_include_definitions = this.includeDefinitionValue;

        // Set wider class name column
        if (BP_include_definitions) {
            class_name_width = "150px";
        } else if (ontology_id === "all") {
            class_name_width = "320px";
        }

        // Results
        const result_type = row[2];
        const result_class = row[0];

        // row[7] is the ontology_id, only included when searching multiple ontologies
        if (ontology_id !== "all") {
            const result_def = row[7];

            if (BP_include_definitions) {
                result += "<div class='result_definition'>" + truncateText(decodeURIComponent(result_def.replace(/\+/g, " ")), 75) + "</div>"
            }

            result += "<div class='result_class' style='width: " + class_name_width + ";'>" + result_class.replace(regex, "<b><span class='result_class_highlight'>$1</span></b>") + "</div>";

            result += "<div class='result_type' style='overflow: hidden;'>" + result_type + "</div>";
        } else {
            // Results
            const result_ont = row[7];
            const result_def = row[9];

            result += "<div class='result_class' style='width: " + class_name_width + ";'>" + result_class.replace(regex, "<b><span class='result_class_highlight'>$1</span></b>") + "</div>"

            if (BP_include_definitions) {
                result += "<div class='result_definition'>" + truncateText(decodeURIComponent(result_def.replace(/\+/g, " ")), 75) + "</div>"
            }

            result += "<div>" + " <div class='result_type'>" + result_type + "</div><div class='result_ontology' style='overflow: hidden;'>" + truncateText(result_ont, 35) + "</div></div>";
        }
        return result;
    }


    onSelect(li) {
        const input = this.element;
        switch (this.targetPropertyValue) {
            case "uri":
                jQuery(input).val(li.extra[3])
                break;
            case "shortid":
                jQuery(input).val(li.extra[0])
                break;
            case "name":
                jQuery(input).val(li.extra[4])
                break;
        }

        const input_name = jQuery(input).attr('name')
        jQuery(`input[name="${input_name}_bioportal_concept_id"]`).val(li.extra[0]);
        jQuery(`input[name="${input_name}_bioportal_ontology_id"]`).val(li.extra[2]);
        jQuery(`input[name="${input_name}_bioportal_full_id"]`).val(li.extra[3]);
        jQuery(`input[name="${input_name}_bioportal_preferred_name"]`).val(li.extra[4]);
    }
    }
}
