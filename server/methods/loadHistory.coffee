Meteor.methods
	loadHistory: (recipe, end, limit=20, ls) ->
		fromId = Meteor.userId()
		# console.log '[methods] loadHistory -> '.green, 'fromId:', fromId, 'rid:', rid, 'end:', end, 'limit:', limit, 'skip:', skip

		options =
			sort:
				ts: -1
			limit: limit

		if not RocketChat.settings.get 'Message_ShowEditedStatus'
			options.fields = { 'editedAt': 0 }

		if end?
			records = RocketChat.models.Messages.findVisibleByRecipeBeforeTimestamp(recipe, end, options).fetch()
		else
			records = RocketChat.models.Messages.findVisibleByRecipe(recipe, options).fetch()

		messages = _.map records, (message) ->
			message.starred = _.findWhere message.starred, { _id: fromId }
			return message

		unreadNotLoaded = 0

		if ls?
			firstMessage = messages[messages.length - 1]
			if firstMessage?.ts > ls
				delete options.limit
				unreadNotLoaded = RocketChat.models.Messages.findVisibleByRecipeBetweenTimestamps(recipe, ls, firstMessage.ts).count()

		return {
			messages: messages
			unreadNotLoaded: unreadNotLoaded
		}
