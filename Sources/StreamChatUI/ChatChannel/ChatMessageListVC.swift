//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import StreamChat
import UIKit

public protocol ChatMessageListVCDataSource: AnyObject {
    associatedtype ExtraData: ExtraDataTypes

    func numberOfMessagesInChatMessageListVC(_ vc: ChatMessageListVC<ExtraData>) -> Int
    func chatMessageListVC(_ vc: ChatMessageListVC<ExtraData>, messageAt index: Int) -> _ChatMessage<ExtraData>
    func loadMoreMessagesForChatMessageListVC(_ vc: ChatMessageListVC<ExtraData>)
    func chatMessageListVC(
        _ vc: ChatMessageListVC<ExtraData>,
        replyMessageFor message: _ChatMessage<ExtraData>,
        at index: Int
    ) -> _ChatMessage<ExtraData>?
    func chatMessageListVC(
        _ vc: ChatMessageListVC<ExtraData>,
        controllerFor message: _ChatMessage<ExtraData>
    ) -> _ChatMessageController<ExtraData>
}

public protocol ChatMessageListVCDelegate: AnyObject {
    associatedtype ExtraData: ExtraDataTypes

    func chatMessageListVC(_ vc: ChatMessageListVC<ExtraData>, didSelectMessageAt index: Int)
    func chatMessageListVC(_ vc: ChatMessageListVC<ExtraData>, didTapOnRepliesFor message: _ChatMessage<ExtraData>)
    func chatMessageListVC(_ vc: ChatMessageListVC<ExtraData>, didTapOnInlineReplyFor message: _ChatMessage<ExtraData>)
    func chatMessageListVC(_ vc: ChatMessageListVC<ExtraData>, didTapOnEdit message: _ChatMessage<ExtraData>)
}

open class ChatMessageListVC<ExtraData: ExtraDataTypes>: ViewController,
    UICollectionViewDataSource,
    UICollectionViewDelegate,
    UIConfigProvider,
    ChatMessageActionsVCDelegate {
    public struct DataSource {
        public var numberOfMessages: (ChatMessageListVC) -> Int
        public var messageAtIndex: (ChatMessageListVC, Int) -> _ChatMessage<ExtraData>
        public var loadMoreMessages: (ChatMessageListVC) -> Void
        public var replyMessageForMessageAtIndex: (ChatMessageListVC, _ChatMessage<ExtraData>, Int) -> _ChatMessage<ExtraData>?
        public var controllerForMessage: (ChatMessageListVC, _ChatMessage<ExtraData>) -> _ChatMessageController<ExtraData>
    }

    public struct Delegate {
        public var didSelectMessageAtIndex: ((ChatMessageListVC, Int) -> Void)?
        public var didTapOnRepliesForMessage: ((ChatMessageListVC, _ChatMessage<ExtraData>) -> Void)?
        public var didTapOnInlineReply: ((ChatMessageListVC, _ChatMessage<ExtraData>) -> Void)?
        public var didTapOnEdit: ((ChatMessageListVC, _ChatMessage<ExtraData>) -> Void)?
    }

    public var dataSource: DataSource = .empty()
    public var delegate: Delegate? // swiftlint:disable:this weak_delegate

    public private(set) lazy var router = uiConfig.navigation.messageListRouter.init(rootViewController: self)

    public private(set) lazy var collectionViewLayout: ChatChannelCollectionViewLayout = uiConfig
        .messageList
        .collectionLayout
        .init()
    public private(set) lazy var collectionView: UICollectionView = {
        let collection = uiConfig.messageList.collectionView.init(layout: collectionViewLayout)
        let incomingCell = uiConfig.messageList.incomingMessageCell
        let outgoingCell = uiConfig.messageList.outgoingMessageCell
        collection.register(incomingCell, forCellWithReuseIdentifier: incomingCell.reuseId)
        collection.register(outgoingCell, forCellWithReuseIdentifier: outgoingCell.reuseId)
        collection.showsHorizontalScrollIndicator = false
        collection.alwaysBounceVertical = true
        collection.keyboardDismissMode = .onDrag
        collection.dataSource = self
        collection.delegate = self

        return collection
    }()

    /// Consider to call `setNeedsScrollToMostRecentMessage(animated:)` instead
    public private(set) var needsToScrollToMostRecentMessage = true
    /// Consider to call `setNeedsScrollToMostRecentMessage(animated:)` instead
    public private(set) var needsToScrollToMostRecentMessageAnimated = false

    /// Consider to call `setLayoutCached(_ value:)` instead
    public private(set) var needsLayoutSwitch = false
    /// Consider to call `setLayoutCached(_ value:)` instead
    public private(set) var newLayoutCachedValue = false

    // MARK: - Life Cycle

    override open func setUp() {
        super.setUp()

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(didLongPress(_:)))
        collectionView.addGestureRecognizer(longPress)
    }

    override open func setUpLayout() {
        super.setUpLayout()

        view.addSubview(collectionView)
        collectionView.pin(to: view.safeAreaLayoutGuide)
        collectionView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
    }

    override public func defaultAppearance() {
        super.defaultAppearance()

        view.backgroundColor = uiConfig.colorPalette.generalBackground
        collectionView.backgroundColor = .clear
    }

    // MARK: - Public API

    /// Will scroll to most recent message on next `updateMessages` call
    public func setNeedsScrollToMostRecentMessage(animated: Bool = true) {
        needsToScrollToMostRecentMessage = true
        needsToScrollToMostRecentMessageAnimated = animated
    }

    /// Force scroll to most recent message check without waiting for `updateMessages`
    public func scrollToMostRecentMessageIfNeeded() {
        if needsToScrollToMostRecentMessage {
            scrollToMostRecentMessage(animated: needsToScrollToMostRecentMessageAnimated)
        }
    }

    public func scrollToMostRecentMessage(animated: Bool = true) {
        needsToScrollToMostRecentMessage = false
        needsToScrollToMostRecentMessageAnimated = false

        // our collection is flipped, so (0; 0) item is most recent one
        collectionView.scrollToItem(at: IndexPath(item: 0, section: 0), at: .bottom, animated: animated)
    }

    public func updateMessages(with changes: [ListChange<_ChatMessage<ExtraData>>], completion: ((Bool) -> Void)? = nil) {
        if let max = collectionView.indexPathsForVisibleItems.map(\.item).max() {
            let hasChangesOnTop = changes.contains { change in
                if case let .insert(_, index) = change, index.item > max {
                    return true
                }
                return false
            }
            if hasChangesOnTop {
                setLayoutCached(false)
            }
        } else {
            setLayoutCached(false)
        }

        collectionView.performBatchUpdates {
            for change in changes {
                switch change {
                case let .insert(_, index):
                    collectionView.insertItems(at: [index])
                case let .move(_, fromIndex, toIndex):
                    collectionView.moveItem(at: fromIndex, to: toIndex)
                case let .remove(_, index):
                    collectionView.deleteItems(at: [index])
                case let .update(_, index):
                    collectionView.reloadItems(at: [index])
                }
            }
        } completion: { flag in
            completion?(flag)
            self.scrollToMostRecentMessageIfNeeded()
        }
    }

    // MARK: - Actions

    @objc func didLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: collectionView)

        guard gesture.state == .began else { return }
        guard let ip = collectionView.indexPathForItem(at: location) else { return }
        guard let cell = collectionView.cellForItem(at: ip) as? СhatMessageCollectionViewCell<ExtraData> else { return }

        didSelectMessageCell(cell)
    }

    // MARK: - Layout optimizations

    public func setLayoutCached(_ value: Bool) {
        needsLayoutSwitch = true
        newLayoutCachedValue = value
        // invalidating layout while collection view is not in idle state, leads to crash
        if collectionView.isDecelerating || collectionView.isDragging {
            return
        }
        // I have no idea why it crashing without dispatch
        DispatchQueue.main.async {
            self.switchLayoutIfNeeded()
        }
    }

    public func switchLayoutIfNeeded() {
        if needsLayoutSwitch {
            collectionViewLayout.layoutCached = newLayoutCachedValue
        }
        needsLayoutSwitch = false
    }

    // MARK: - UICollectionViewDataSource

    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        dataSource.numberOfMessages(self)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let message = messageGroupPart(at: indexPath)

        let cell: СhatMessageCollectionViewCell<ExtraData>
        if message.isSentByCurrentUser {
            cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: uiConfig.messageList.outgoingMessageCell.reuseId,
                for: indexPath
            ) as! СhatMessageCollectionViewCell<ExtraData>
        } else {
            cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: uiConfig.messageList.incomingMessageCell.reuseId,
                for: indexPath
            ) as! СhatMessageCollectionViewCell<ExtraData>
        }

        cell.messageView.onThreadTap = { [weak self] in
            guard let self = self, let message = $0?.message else { return }
            self.delegate?.didTapOnRepliesForMessage?(self, message)
        }
        cell.messageView.onErrorIndicatorTap = { [weak self, weak cell] _ in
            guard let self = self, let cell = cell else { return }
            self.didSelectMessageCell(cell)
        }
        cell.messageView.onLinkTap = { [weak self] link in
            if let link = link {
                self?.didTapOnLink(link)
            }
        }
        cell.message = message

        return cell
    }

    // MARK: - UICollectionViewDelegate

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        delegate?.didSelectMessageAtIndex?(self, indexPath.row)
    }

    public func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if indexPath.row + 1 >= collectionView.numberOfItems(inSection: 0) {
            dataSource.loadMoreMessages(self)
            setLayoutCached(true)
        }
    }

    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        switchLayoutIfNeeded()
    }

    // MARK: - ChatMessageActionsVCDelegate

    open func chatMessageActionsVC(
        _ vc: ChatMessageActionsVC<ExtraData>,
        didTapOnInlineReplyFor message: _ChatMessage<ExtraData>
    ) {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapOnInlineReply?(self, message)
        }
    }

    open func chatMessageActionsVC(
        _ vc: ChatMessageActionsVC<ExtraData>,
        didTapOnThreadReplyFor message: _ChatMessage<ExtraData>
    ) {
        dismiss(animated: true)
    }

    open func chatMessageActionsVC(
        _ vc: ChatMessageActionsVC<ExtraData>,
        didTapOnEdit message: _ChatMessage<ExtraData>
    ) {
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.didTapOnEdit?(self, message)
        }
    }

    open func chatMessageActionsVCDidFinish(_ vc: ChatMessageActionsVC<ExtraData>) {
        dismiss(animated: true)
    }

    // MARK: - Private

    private func messageGroupPart(at indexPath: IndexPath) -> _ChatMessageGroupPart<ExtraData> {
        let message = dataSource.messageAtIndex(self, indexPath.row)

        var isLastInGroup: Bool {
            guard indexPath.row > 0 else { return true }
            let nextMessage = dataSource.messageAtIndex(self, indexPath.row - 1)
            guard nextMessage.author == message.author else { return true }
            let delay = nextMessage.createdAt.timeIntervalSince(message.createdAt)
            return delay > uiConfig.messageList.minTimeInvteralBetweenMessagesInGroup
        }

        return .init(
            message: message,
            quotedMessage: dataSource.replyMessageForMessageAtIndex(self, message, indexPath.row),
            isLastInGroup: isLastInGroup,
            didTapOnAttachment: { [weak self] attachment in
                self?.didTapOnAttachment(attachment, in: message)
            },
            didTapOnAttachmentAction: { [weak self] _, action in
                guard let self = self else { return }

                let messageController = self.dataSource.controllerForMessage(self, message)
                messageController.dispatchEphemeralMessageAction(action)
            }
        )
    }

    private func didSelectMessageCell(_ cell: СhatMessageCollectionViewCell<ExtraData>) {
        guard let messageData = cell.message, messageData.isInteractionEnabled else { return }

        let actionsController = ChatMessageActionsVC<ExtraData>()
        actionsController.messageController = dataSource.controllerForMessage(self, messageData.message)
        actionsController.delegate = .init(delegate: self)

        var reactionsController: ChatMessageReactionVC<ExtraData>? {
            guard messageData.message.localState == nil else { return nil }

            let controller = ChatMessageReactionVC<ExtraData>()
            controller.messageController = dataSource.controllerForMessage(self, messageData.message)
            return controller
        }

        router.showMessageActionsPopUp(
            messageContentFrame: cell.messageView.superview!.convert(cell.messageView.frame, to: nil),
            messageData: messageData,
            messageActionsController: actionsController,
            messageReactionsController: reactionsController
        )
    }

    private func didTapOnAttachment(_ attachment: _ChatMessageAttachment<ExtraData>, in message: _ChatMessage<ExtraData>) {
        switch attachment.localState {
        case .uploadingFailed:
            let messageController = dataSource.controllerForMessage(self, message)
            messageController.restartFailedAttachmentUploading(with: attachment.id)
        default:
            router.showPreview(for: attachment)
        }
    }

    private func didTapOnLink(_ link: _ChatMessageAttachment<ExtraData>) {
        router.openLink(link)
    }
}

public extension ChatMessageListVC.DataSource {
    static func wrap<T: ChatMessageListVCDataSource>(_ ds: T) -> ChatMessageListVC.DataSource where T.ExtraData == ExtraData {
        ChatMessageListVC.DataSource(
            numberOfMessages: { [unowned ds] in ds.numberOfMessagesInChatMessageListVC($0) },
            messageAtIndex: { [unowned ds] in ds.chatMessageListVC($0, messageAt: $1) },
            loadMoreMessages: { [unowned ds] in ds.loadMoreMessagesForChatMessageListVC($0) },
            replyMessageForMessageAtIndex: { [unowned ds] in ds.chatMessageListVC($0, replyMessageFor: $1, at: $2) },
            controllerForMessage: { [unowned ds] in ds.chatMessageListVC($0, controllerFor: $1) }
        )
    }

    static func empty() -> ChatMessageListVC.DataSource {
        ChatMessageListVC.DataSource(
            numberOfMessages: { _ in 0 },
            messageAtIndex: { _, _ in
                fatalError("Method shouldn't be called on empty data source")
            },
            loadMoreMessages: { _ in },
            replyMessageForMessageAtIndex: { _, _, _ in nil },
            controllerForMessage: { _, _ in
                fatalError("Method shouldn't be called on empty data source")
            }
        )
    }
}

public extension ChatMessageListVC.Delegate {
    static func wrap<T: ChatMessageListVCDelegate>(_ delegate: T) -> ChatMessageListVC.Delegate where T.ExtraData == ExtraData {
        ChatMessageListVC.Delegate(
            didSelectMessageAtIndex: { [weak delegate] in delegate?.chatMessageListVC($0, didSelectMessageAt: $1) },
            didTapOnRepliesForMessage: { [weak delegate] in delegate?.chatMessageListVC($0, didTapOnRepliesFor: $1) },
            didTapOnInlineReply: { [weak delegate] in delegate?.chatMessageListVC($0, didTapOnInlineReplyFor: $1) },
            didTapOnEdit: { [weak delegate] in delegate?.chatMessageListVC($0, didTapOnEdit: $1) }
        )
    }
}
