import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  

    addContact(event) {
        event.preventDefault();
        var contacts = document.querySelectorAll("div.contact");
        var newContact = contacts[0].cloneNode(true);
        var removeButton = newContact.querySelector("button").cloneNode(true);
        removeButton.classList.replace("btn-success", "btn-danger");
        removeButton.classList.replace("add-contact", "remove-contact");
        removeButton.dataset.action = "click->contact#removeContact"
        removeButton.classList.add("ml-1")
        removeButton.querySelector("i").classList.replace("fa-plus", "fa-minus");
        newContact.appendChild(removeButton);
        var index = contacts.length;
        var inputs = newContact.getElementsByTagName("input");
        for (var i = 0; i < inputs.length; i++) {
          var input = inputs[i];
      
          var id = input.getAttribute("id").replace(/0/g, index);
          input.setAttribute("id", id);
      
          var name = input.getAttribute("name").replace(/0/g, index);
          input.setAttribute("name", name);
          
          input.setAttribute("value", "");
      
          input.removeAttribute("required");
        }
      
        contacts[index - 1].insertAdjacentElement('afterend', newContact);
      }

    removeContact(event) {
        event.preventDefault();
        var target = event.target;
        var contact;
        if (target.matches("button.remove-contact")) {
          console.log("hi")
          contact = target.parentNode;
        } else if (target.matches("i.fa-minus")) {
          console.log("hello")
        contact = target.parentNode.parentNode;
        }
        document.querySelector("#contacts").removeChild(contact);
    }
    
}