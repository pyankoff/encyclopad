@RoomHistoryManager = new class
	defaultLimit = 50

	histories = {}

	getRoom = (recipe) ->
		if not histories[recipe]?
			histories[recipe] =
				hasMore: ReactiveVar true
				isLoading: ReactiveVar false
				unreadNotLoaded: ReactiveVar 0
				loaded: 0

		return histories[recipe]

	getMore = (recipe, limit=defaultLimit) ->
		room = getRoom recipe
		if room.hasMore.curValue isnt true
			return

		room.isLoading.set true

		# ScrollListener.setLoader true
		lastMessage = ChatMessage.findOne({tags: recipe}, {sort: {ts: 1}})
		# lastMessage ?= ChatMessage.findOne({rid: rid}, {sort: {ts: 1}})

		if lastMessage?
			ts = lastMessage.ts
		else
			ts = undefined

		ls = undefined
		typeName = undefined

		subscription = ChatSubscription.findOne name: recipe
		if subscription?
			ls = subscription.ls
			typeName = subscription.t + subscription.name
		else
			curRoomDoc = ChatRoom.findOne(name: recipe)
			typeName = curRoomDoc?.t + curRoomDoc?.name

		Meteor.call 'loadHistory', recipe, ts, limit, ls, (err, result) ->
			room.unreadNotLoaded.set result?.unreadNotLoaded

			wrapper = $('.messages-box .wrapper').get(0)
			if wrapper?
				previousHeight = wrapper.scrollHeight

			ChatMessage.upsert {_id: item._id}, item for item in result?.messages or []

			if wrapper?
				heightDiff = wrapper.scrollHeight - previousHeight
				wrapper.scrollTop += heightDiff

			Meteor.defer ->
				readMessage.refreshUnreadMark(recipe, true)
				RoomManager.updateMentionsMarksOfRoom typeName

			room.isLoading.set false
			room.loaded += result?.messages?.length
			if result?.messages?.length < limit
				room.hasMore.set false

	hasMore = (recipe) ->
		room = getRoom recipe

		return room.hasMore.get()

	getMoreIfIsEmpty = (recipe) ->
		room = getRoom recipe

		if room.loaded is 0
			getMore recipe

	isLoading = (recipe) ->
		room = getRoom recipe

		return room.isLoading.get()

	clear = (recipe) ->
		ChatMessage.remove({ tags: recipe })
		if histories[recipe]?
			histories[recipe].hasMore.set true
			histories[recipe].isLoading.set false
			histories[recipe].loaded = 0

	getRoom: getRoom
	getMore: getMore
	getMoreIfIsEmpty: getMoreIfIsEmpty
	hasMore: hasMore
	isLoading: isLoading
	clear: clear
