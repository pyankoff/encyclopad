Meteor.methods
	loadMissedMessages: (recipe, start) ->
		fromId = Meteor.userId()
		# console.log '[methods] loadMissedMessages -> '.green, 'fromId:', fromId, 'rid:', rid, 'start:', start

		options =
			sort:
				ts: -1

		if not RocketChat.settings.get 'Message_ShowEditedStatus'
			options.fields = { 'editedAt': 0 }

		return RocketChat.models.Messages.findVisibleByRecipeAfterTimestamp(recipe, start, options).fetch()
