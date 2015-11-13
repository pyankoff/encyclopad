RocketChat.sendMessage = (user, message, options) ->

	if not user or not message
		return false

	unless message.ts?
		message.ts = new Date()

	message.u = _.pick user, ['_id','username']

	if urls = message.msg.match /([A-Za-z]{3,9}):\/\/([-;:&=\+\$,\w]+@{1})?([-A-Za-z0-9\.]+)+:?(\d+)?((\/[-\+=!:~%\/\.@\,\w]+)?\??([-\+=&!:;%@\/\.\,\w]+)?#?([\w]+)?)?/g
		message.urls = urls.map (url) -> url: url

	message = RocketChat.callbacks.run 'beforeSaveMessage', message

	if message._id? and options?.upsert is true
		RocketChat.models.Messages.upsert {_id: message._id}, message
	else
		message._id = RocketChat.models.Messages.insert message

	###
	Defer other updates as their return is not interesting to the user
	###

	###
	Execute all callbacks
	###
	Meteor.defer ->

		RocketChat.callbacks.run 'afterSaveMessage', message

	###
	Update all the room activity tracker fields
	###
	Meteor.defer ->
		RocketChat.models.Rooms.incUnreadAndSetLastMessageTimestampById message.tags, 1, message.ts

	return message
