import Controller from "@ember/controller";
import { action } from "@ember/object";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import showModal from "discourse/lib/show-modal";

export default class ChatChannelInfoAboutController extends Controller.extend(
  ModalFunctionality
) {
  @action
  onEditChatChannelTitle() {
    showModal("chat-channel-edit-title", { model: this.model });
  }

  @action
  onEditChatChannelDescription() {
    showModal("chat-channel-edit-description", {
      model: this.model,
    });
  }
}
