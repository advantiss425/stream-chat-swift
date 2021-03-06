//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

open class ChatMessageListRouter<ExtraData: ExtraDataTypes>: ChatRouter<ChatMessageListVC<ExtraData>> {
    open func showMessageActionsPopUp(
        messageContentFrame: CGRect,
        messageData: _ChatMessageGroupPart<ExtraData>,
        messageActionsController: ChatMessageActionsVC<ExtraData>,
        messageReactionsController: ChatMessageReactionVC<ExtraData>?
    ) {
        let popup = ChatMessagePopupViewController<ExtraData>()
        popup.message = messageData
        popup.messageViewFrame = messageContentFrame
        popup.actionsController = messageActionsController
        popup.reactionsController = messageReactionsController
        popup.modalPresentationStyle = .overFullScreen
        popup.modalTransitionStyle = .crossDissolve

        rootViewController.present(popup, animated: true)
    }
    
    open func showPreview(for attachment: _ChatMessageAttachment<ExtraData>) {
        let preview = ChatAttachmentPreviewVC()
        preview.content = attachment.type == .file ? attachment.url : attachment.imageURL
        
        let navigation = UINavigationController(rootViewController: preview)
        rootViewController.present(navigation, animated: true)
    }

    open func openLink(_ link: _ChatMessageAttachment<ExtraData>) {
        let preview = ChatAttachmentPreviewVC()
        preview.content = link.url

        let navigation = UINavigationController(rootViewController: preview)
        rootViewController.present(navigation, animated: true)
    }
}
