favoritesEnabled = ->
	return !RocketChat.settings.get 'Disable_Favorite_Rooms'


Template.room.helpers
	showFormattingTips: ->
		return RocketChat.settings.get('Message_ShowFormattingTips') and (RocketChat.Markdown or RocketChat.Highlight)
	showMarkdown: ->
		return RocketChat.Markdown
	showHighlight: ->
		return RocketChat.Highlight
	favorite: ->
		sub = ChatSubscription.findOne { name: Session.get('recipe') }, { fields: { f: 1 } }
		return 'icon-star favorite-room' if sub?.f? and sub.f and favoritesEnabled
		return 'icon-star-empty'

	messagesHistory: ->
		recipe = Session.get('recipe')
		return ChatMessage.find { tags: recipe, t: { '$ne': 't' }  }, { sort: { ts: 1 } }

	hasMore: ->
		return RoomHistoryManager.hasMore Session.get('recipe')

	isLoading: ->
		return RoomHistoryManager.isLoading Session.get('recipe')

	windowId: ->
		return "chat-window-#{this._id}"

	uploading: ->
		return Session.get 'uploading'

	roomIcon: ->
		roomData = Session.get('roomData' + this._id)
		return '' unless roomData?.t

		switch roomData.t
			when 'd' then return 'icon-at'
			when 'c' then return 'icon-hash'
			when 'p' then return 'icon-lock'

	autocompleteSettingsRoomSearch: ->
		return {
			limit: 10
			# inputDelay: 300
			rules: [
				{
					collection: 'UserAndRoom'
					subscription: 'roomSearch'
					field: 'name'
					template: Template.roomSearch
					noMatchTemplate: Template.roomSearchEmpty
					matchAll: true
					filter: { uid: { $ne: Meteor.userId() } }
					sort: 'name'
				}
			]
		}

	isChannel: ->
		roomData = Session.get('roomData' + this._id)
		return '' unless roomData
		return roomData.t is 'c'

	canEditName: ->
		roomData = Session.get('roomData' + this._id)
		return '' unless roomData
		if roomData.t in ['c', 'p']
			return RocketChat.authz.hasAtLeastOnePermission('edit-room', this._id)
		else
			return ''

	arrowPosition: ->
		return 'left' unless RocketChat.TabBar.isFlexOpen()

	userActiveByUsername: (username) ->
		status = Session.get 'user_' + username + '_status'
		if status in ['online', 'away', 'busy']
			return {username: username, status: status}
		return

	seeAll: ->
		if Template.instance().showUsersOffline.get()
			return t('See_only_online')
		else
			return t('See_all')

	getPopupConfig: ->
		template = Template.instance()
		return {
			getInput: ->
				return template.find('.input-message')
		}

	maxMessageLength: ->
		return RocketChat.settings.get('Message_MaxAllowedSize')

	utc: ->
		if @utcOffset?
			return "UTC #{@utcOffset}"

	lastLogin: ->
		if @lastLogin
			return moment(@lastLogin).format('LLL')

	canJoin: ->
		return !! ChatRoom.findOne { _id: @_id, t: 'c' }

	unreadSince: ->
		room = ChatRoom.findOne(this._id, { reactive: false })
		if room?
			return RoomManager.openedRooms[room.t + room.name]?.unreadSince?.get()

	unreadCount: ->
		return RoomHistoryManager.getRoom(Session.get('recipe')).unreadNotLoaded.get() + Template.instance().unreadCount.get()

	formatUnreadSince: ->
		room = ChatRoom.findOne(this._id, { reactive: false })
		room = RoomManager.openedRooms[room.t + room.name]
		date = room?.unreadSince.get()
		if not date? then return

		return moment(date).calendar(null, {sameDay: 'LT'})

	flexTemplate: ->
		return RocketChat.TabBar.getTemplate()

	flexData: ->
		return _.extend { rid: this._id }, RocketChat.TabBar.getData()

	adminClass: ->
		return 'admin' if RocketChat.authz.hasRole(Meteor.userId(), 'admin')

	showToggleFavorite: ->
		return true if isSubscribed(this._id) and favoritesEnabled()

	compactView: ->
		return 'compact' if Meteor.user()?.settings?.preferences?.compactView

	fileUploadAllowedMediaTypes: ->
		return RocketChat.settings.get('FileUpload_MediaTypeWhiteList')


Template.room.events
	"click, touchend": (e, t) ->
		Meteor.setTimeout ->
			t.sendToBottomIfNecessaryDebounced()
		, 100

	"touchstart .message": (e, t) ->
		message = this._arguments[1]
		doLongTouch = ->
			mobileMessageMenu.show(message, t)

		t.touchtime = Meteor.setTimeout doLongTouch, 500

	"touchend .message": (e, t) ->
		Meteor.clearTimeout t.touchtime

	"touchmove .message": (e, t) ->
		Meteor.clearTimeout t.touchtime

	"touchcancel .message": (e, t) ->
		Meteor.clearTimeout t.touchtime

	"click .upload-progress > a": ->
		Session.set "uploading-cancel-#{this.id}", true

	"click .unread-bar > a": ->
		readMessage.readNow(true)

	"click .flex-tab .more": (event, t) ->
		if RocketChat.TabBar.isFlexOpen()
			Session.set('rtcLayoutmode', 0)
			RocketChat.TabBar.closeFlex()
			t.searchResult.set undefined
		else
			RocketChat.TabBar.openFlex()


	"click .flex-tab  .video-remote" : (e) ->
		if RocketChat.TabBar.isFlexOpen()
			if (!Session.get('rtcLayoutmode'))
				Session.set('rtcLayoutmode', 1)
			else
				t = Session.get('rtcLayoutmode')
				t = (t + 1) % 4
				console.log  'setting rtcLayoutmode to ' + t  if window.rocketDebug
				Session.set('rtcLayoutmode', t)

	"click .flex-tab  .video-self" : (e) ->
		if (Session.get('rtcLayoutmode') == 3)
			console.log 'video-self clicked in layout3' if window.rocketDebug
			i = document.getElementById("fullscreendiv")
			if i.requestFullscreen
				i.requestFullscreen()
			else
				if i.webkitRequestFullscreen
					i.webkitRequestFullscreen()
				else
					if i.mozRequestFullScreen
						i.mozRequestFullScreen()
					else
						if i.msRequestFullscreen
							i.msRequestFullscreen()

	'click .toggle-favorite': (event) ->
		event.stopPropagation()
		event.preventDefault()
		Meteor.call 'toogleFavorite', @_id, !$('i', event.currentTarget).hasClass('favorite-room')

	'click .join': (event) ->
		event.stopPropagation()
		event.preventDefault()
		Meteor.call 'joinRoom', @_id

	'focus .input-message': (event) ->
		KonchatNotification.removeRoomNotification @_id

	'keyup .input-message': (event) ->
		Template.instance().chatMessages.keyup(@_id, event, Template.instance())

	'paste .input-message': (e) ->
		if not e.originalEvent.clipboardData?
			return

		items = e.originalEvent.clipboardData.items
		files = []
		for item in items
			if item.kind is 'file' and item.type.indexOf('image/') isnt -1
				e.preventDefault()
				files.push
					file: item.getAsFile()
					name: 'Clipboard'

		if files.length > 0
			fileUpload files

	'keydown .input-message': (event) ->
		recipe = Session.get('recipe')
		Template.instance().chatMessages.keydown(recipe, event, Template.instance())

	'click .message-form .icon-paper-plane': (event) ->
		input = $(event.currentTarget).siblings("textarea")
		Template.instance().chatMessages.send(this._id, input.get(0))
		event.preventDefault()
		event.stopPropagation()
		input.focus()
		input.get(0).updateAutogrow()

	'keydown #recipe-field': (event) ->
		if event.keyCode is 27 # esc
			Session.set('editRoomTitle', false)
		else if event.keyCode is 13 # enter
			Session.set('recipe', $(event.currentTarget).val())

	'blur #recipe-field': (event) ->
		Session.set('editRoomTitle', false)
		$(".fixed-title").removeClass "visible"

	"click .flex-tab .user-image > a" : (e) ->
		RocketChat.TabBar.openFlex()
		Session.set('showUserInfo', $(e.currentTarget).data('username'))

	'click .user-card-message': (e) ->
		roomData = Session.get('roomData' + this._arguments[1].rid)
		if roomData.t in ['c', 'p']
			# Session.set('flexOpened', true)
			Session.set('showUserInfo', $(e.currentTarget).data('username'))
		# else
			# Session.set('flexOpened', true)
		RocketChat.TabBar.setTemplate 'membersList'

	'scroll .wrapper': _.throttle (e, instance) ->
		if RoomHistoryManager.hasMore(Session.get('recipe')) is true and RoomHistoryManager.isLoading(Session.get('recipe')) is false
			if e.target.scrollTop is 0
				RoomHistoryManager.getMore(Session.get('recipe'))
	, 200

	'click .load-more > a': ->
		RoomHistoryManager.getMore(Session.get('recipe'))

	'click .new-message': (e) ->
		Template.instance().atBottom = true
		Template.instance().find('.input-message').focus()

	'click .see-all': (e, instance) ->
		instance.showUsersOffline.set(!instance.showUsersOffline.get())

	'click .message-cog': (e) ->
		message_id = $(e.currentTarget).closest('.message').attr('id')
		$('.message-dropdown:visible').hide()
		$(".messages-box \##{message_id} .message-dropdown").show()

	'click .message-dropdown-close': ->
		$('.message-dropdown:visible').hide()

	"click .editing-commands-cancel > a": (e) ->
		Template.instance().chatMessages.clearEditing()

	"click .editing-commands-save > a": (e) ->
		chatMessages = Template.instance().chatMessages
		chatMessages.send(@_id, chatMessages.input)

	"click .mention-link": (e) ->
		channel = $(e.currentTarget).data('channel')
		if channel?
			FlowRouter.go 'channel', {name: channel}
			return

		RocketChat.TabBar.setTemplate 'membersList'
		Session.set('showUserInfo', $(e.currentTarget).data('username'))
		RocketChat.TabBar.openFlex()

	'click .image-to-download': (event) ->
		ChatMessage.update {_id: this._arguments[1]._id, 'urls.url': $(event.currentTarget).data('url')}, {$set: {'urls.$.downloadImages': true}}

	'click .pin-message': (event) ->
		message = @_arguments[1]
		instance = Template.instance()

		if message.pinned
			instance.chatMessages.unpinMsg(message)
		else
			instance.chatMessages.pinMsg(message)

	'dragenter .dropzone': (e) ->
		e.currentTarget.classList.add 'over'

	'dragleave .dropzone-overlay': (e) ->
		e.currentTarget.parentNode.classList.remove 'over'

	'dropped .dropzone-overlay': (event) ->
		event.currentTarget.parentNode.classList.remove 'over'

		e = event.originalEvent or event
		files = e.target.files
		if not files or files.length is 0
			files = e.dataTransfer?.files or []

		filesToUpload = []
		for file in files
			filesToUpload.push
				file: file
				name: file.name

		fileUpload filesToUpload

	'change .message-form input[type=file]': (event, template) ->
		e = event.originalEvent or event
		files = e.target.files
		if not files or files.length is 0
			files = e.dataTransfer?.files or []

		filesToUpload = []
		for file in files
			filesToUpload.push
				file: file
				name: file.name

		fileUpload filesToUpload

	'click .deactivate': ->
		username = Session.get('showUserInfo')
		user = Meteor.users.findOne { username: String(username) }
		Meteor.call 'setUserActiveStatus', user?._id, false, (error, result) ->
			if result
				toastr.success t('User_has_been_deactivated')
			if error
				toastr.error error.reason

	'click .activate': ->
		username = Session.get('showUserInfo')
		user = Meteor.users.findOne { username: String(username) }
		Meteor.call 'setUserActiveStatus', user?._id, true, (error, result) ->
			if result
				toastr.success t('User_has_been_activated')
			if error
				toastr.error error.reason

	'load img': (e, template) ->
		template.sendToBottomIfNecessary?()


Template.room.onCreated ->
	# this.scrollOnBottom = true
	# this.typing = new msgTyping this.data._id
	this.showUsersOffline = new ReactiveVar false
	this.atBottom = true
	this.unreadCount = new ReactiveVar 0

	self = @

	@autorun ->
		self.subscribe 'fullUserData', Session.get('showUserInfo'), 1

	Session.set('recipe', FlowRouter.getParam('name'))

	for button in RocketChat.MessageAction.getButtons()
		if _.isFunction button.action
			evt = {}
			evt["click .#{button.id}"] = button.action
			Template.room.events evt


Template.room.onDestroyed ->
	window.removeEventListener 'resize', this.onWindowResize


Template.room.onRendered ->
	this.chatMessages = new ChatMessages
	this.chatMessages.init(this.firstNode)
	# ScrollListener.init()

	wrapper = this.find('.wrapper')
	wrapperUl = this.find('.wrapper > ul')
	newMessage = this.find(".new-message")

	template = this

	containerBars = $('.messages-container > .container-bars')
	containerBarsOffset = containerBars.offset()

	template.isAtBottom = ->
		if wrapper.scrollTop >= wrapper.scrollHeight - wrapper.clientHeight
			newMessage.className = "new-message not"
			return true
		return false

	template.sendToBottom = ->
		wrapper.scrollTop = wrapper.scrollHeight - wrapper.clientHeight
		newMessage.className = "new-message not"

	template.checkIfScrollIsAtBottom = ->
		template.atBottom = template.isAtBottom()
		readMessage.enable()
		readMessage.read()

	template.sendToBottomIfNecessary = ->
		if template.atBottom is true and template.isAtBottom() isnt true
			template.sendToBottom()

	template.sendToBottomIfNecessaryDebounced = _.debounce template.sendToBottomIfNecessary, 10

	template.sendToBottomIfNecessary()

	if not window.MutationObserver?
		wrapperUl.addEventListener 'DOMSubtreeModified', ->
			template.sendToBottomIfNecessaryDebounced()
	else
		observer = new MutationObserver (mutations) ->
			mutations.forEach (mutation) ->
				template.sendToBottomIfNecessaryDebounced()

		observer.observe wrapperUl,
			childList: true
		# observer.disconnect()

	template.onWindowResize = ->
		Meteor.defer ->
			template.sendToBottomIfNecessaryDebounced()

	window.addEventListener 'resize', template.onWindowResize

	wrapper.addEventListener 'mousewheel', ->
		template.atBottom = false
		Meteor.defer ->
			template.checkIfScrollIsAtBottom()

	wrapper.addEventListener 'wheel', ->
		template.atBottom = false
		Meteor.defer ->
			template.checkIfScrollIsAtBottom()

	wrapper.addEventListener 'touchstart', ->
		template.atBottom = false

	wrapper.addEventListener 'touchend', ->
		Meteor.defer ->
			template.checkIfScrollIsAtBottom()
		Meteor.setTimeout ->
			template.checkIfScrollIsAtBottom()
		, 1000
		Meteor.setTimeout ->
			template.checkIfScrollIsAtBottom()
		, 2000

	$('.flex-tab-bar').on 'click', (e, t) ->
		Meteor.setTimeout ->
			template.sendToBottomIfNecessaryDebounced()
		, 100

	updateUnreadCount = _.throttle ->
		firstMessageOnScreen = document.elementFromPoint(containerBarsOffset.left+1, containerBarsOffset.top+containerBars.height()+1)
		if firstMessageOnScreen?.id?
			firstMessage = ChatMessage.findOne firstMessageOnScreen.id
			if firstMessage?
				subscription = ChatSubscription.findOne name: Session.get('recipe')
				template.unreadCount.set ChatMessage.find({tags: Session.get('recipe'), ts: {$lt: firstMessage.ts, $gt: subscription.ls}}).count()
			else
				template.unreadCount.set 0
	, 300

	# salva a data da renderização para exibir alertas de novas mensagens
	$.data(this.firstNode, 'renderedAt', new Date)
