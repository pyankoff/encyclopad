Package.describe({
	name: 'rocketchat:external',
	version: '0.0.1',
	summary: 'External for Rocket.Chat'
});

Package.onUse(function(api) {
	api.versionsFrom('1.0');

	api.use('coffeescript', 'server');
	api.use('webapp', 'server');
	api.use('autoupdate', 'server');

	api.addFiles('external.coffee', 'server');

	api.addFiles('public/external.css', 'client', {isAsset: true});
	api.addFiles('public/external.js', 'client', {isAsset: true});
	api.addFiles('public/head.html', 'server', {isAsset: true});
});
