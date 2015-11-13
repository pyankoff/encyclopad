Meteor.methods
	sendMessage: (message, options) ->
		if message.msg?.length > RocketChat.settings.get('Message_MaxAllowedSize')
			throw new Meteor.Error 400, '[methods] sendMessage -> Message size exceed Message_MaxAllowedSize'

		if not Meteor.userId()
			throw new Meteor.Error('invalid-user', "[methods] sendMessage -> Invalid user")

		console.log '[methods] sendMessage -> '.green, 'userId:', Meteor.userId(), 'arguments:', arguments

		user = RocketChat.models.Users.findOneById Meteor.userId(), fields: username: 1

		RocketChat.sendMessage user, message, options

# Limit a user to sending 5 msgs/second
DDPRateLimiter.addRule
	type: 'method'
	name: 'sendMessage'
	userId: (userId) ->
		return RocketChat.models.Users.findOneById(userId)?.username isnt RocketChat.settings.get('RocketBot_Name')
, 5, 1000
