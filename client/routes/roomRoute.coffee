FlowRouter.route '/channel/:name',
	name: 'channel'

	action: (params, queryParams) ->
		Session.set 'showUserInfo'
		openRoom 'c', params.name

	triggersExit: [roomExit]
