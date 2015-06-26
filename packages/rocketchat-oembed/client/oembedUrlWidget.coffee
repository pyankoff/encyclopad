Template.oembedUrlWidget.helpers
	description: ->
		if not this.meta?
			return

		return this.meta.ogDescription or this.meta.twitterDescription or this.meta.description

	title: ->
		if not this.meta?
			return

		return this.meta.ogTitle or this.meta.twitterTitle or this.meta.title or this.meta.pageTitle

	image: ->
		if not this.meta?
			return

		return this.meta.ogImage or this.meta.twitterImage