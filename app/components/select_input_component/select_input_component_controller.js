import {Controller} from "@hotwired/stimulus"
import {useChosen} from "../../javascript/mixins/useChosen";

export default class extends Controller {

    static values = {
        other: {type: Boolean, default: true},
        multiple: {type: Boolean, default: false}
    }

    static targets = ["btnValueField", "inputValueField", "selectedValues"]

    connect() {
        if (this.multipleValue) {
            this.initMultipleSelect()
            this.#displayOtherValueField()
        }
    }

    toggleOtherValue() {
        if (this.otherValue && !this.multipleValue) {
            this.#toggle()
        }
    }

    addValue(event) {
        event.preventDefault()

        if (this.inputValueFieldTarget.value) {
            let newOption = this.inputValueFieldTarget.value;
            this.#addNewOption(newOption)
            this.#selectNewOption(newOption)
            if (!this.multipleValue){
                this.#hideOtherValueField()
            }
        }
    }


    initMultipleSelect() {
        useChosen(this.selectedValuesTarget, {
            width: '100%',
            search_contains: true
        })
    }

    #selectNewOption(newOption) {
        let selectedOptions = this.#selectedOptions();


        if (Array.isArray(selectedOptions)) {
            selectedOptions.push(newOption);
        } else {
            selectedOptions = [];
            selectedOptions.push(newOption)
        }

        this.selectedValuesTarget.value = selectedOptions
        if (this.multipleValue) {
            const options = this.selectedValuesTarget.options
            for (const element of options) {
                element.selected = selectedOptions.indexOf(element.value) >= 0;
            }
            jQuery(this.selectedValuesTarget).trigger("chosen:updated")
        }

    }

    #addNewOption(newOption) {
        let option = document.createElement("option");
        option.value = newOption;
        option.text = newOption;
        this.selectedValuesTarget.add(option)
    }

    #selectedOptions() {
        if (this.multipleValue) {
            const selectedOptions = [];
            for (let option of this.selectedValuesTarget.options) {
                if (option.selected) {
                    selectedOptions.push(option.value);
                }
            }
            return selectedOptions
        } else {
            return this.selectedValuesTarget.value
        }
    }

    #toggle() {
        if (this.selectedValuesTarget.value === 'other') {
            this.#displayOtherValueField()
        } else {
            this.#hideOtherValueField()
        }
    }

    #displayOtherValueField() {
        this.inputValueFieldTarget.value = ""
        this.btnValueFieldTarget.style.display = 'block'
        this.inputValueFieldTarget.style.display = 'block'
    }

    #hideOtherValueField() {
        this.inputValueFieldTarget.value = ""
        this.btnValueFieldTarget.style.display = 'none'
        this.inputValueFieldTarget.style.display = 'none'
    }


}