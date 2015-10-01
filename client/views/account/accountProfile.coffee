Template.accountProfile.helpers
	languages: ->
		languages = TAPi18n.getLanguages()
		result = []
		for key, language of languages
			result.push _.extend(language, { key: key })
		return _.sortBy(result, 'key')

	userLanguage: (key) ->
		return (localStorage.getItem('userLanguage') or defaultUserLanguage())?.split('-').shift().toLowerCase() is key

	username: ->
		return Meteor.user().username

Template.accountProfile.onCreated ->
	settingsTemplate = this.parentTemplate(3)
	settingsTemplate.child ?= []
	settingsTemplate.child.push this

	@clearForm = ->
		@find('#language').value = localStorage.getItem('userLanguage')
		@find('#oldPassword').value = ''
		@find('#password').value = ''

	@changePassword = (oldPassword, newPassword, callback) ->
		if not oldPassword and not newPassword
			return callback()

		else if !!oldPassword ^ !!newPassword
			toastr.warning t('Old_and_new_password_required')

		else if newPassword and oldPassword
			Accounts.changePassword oldPassword, newPassword, (error) ->
				if error
					toastr.error t('Incorrect_Password')
				else
					return callback()

	@save = ->
		instance = @

		oldPassword = _.trim($('#oldPassword').val())
		newPassword = _.trim($('#password').val())

		instance.changePassword oldPassword, newPassword, ->
			data = {}
			reload = false
			selectedLanguage = $('#language').val()

			if localStorage.getItem('userLanguage') isnt selectedLanguage
				localStorage.setItem 'userLanguage', selectedLanguage
				data.language = selectedLanguage
				reload = true

			if _.trim $('#username').val()
				data.username = _.trim $('#username').val()

			Meteor.call 'saveUserProfile', data, (error, results) ->
				if results
					toastr.success t('Profile_saved_successfully')
					instance.clearForm()
					if reload
						setTimeout ->
							Meteor._reload.reload()
						, 1000

				if error
					toastr.error error.reason

Template.accountProfile.onRendered ->
	Tracker.afterFlush ->
		SideNav.setFlex "accountFlex"
		SideNav.openFlex()

Template.accountProfile.events
	'click .submit button': (e, t) ->
		t.save()
