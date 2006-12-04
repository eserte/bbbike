function install(link) {
	if (typeof(window.external) != 'undefined' && typeof(window.external.AddSearchProvider) != 'undefined') {
		window.external.AddSearchProvider(link.href);
		return false;
	} else if (window.sidebar && window.sidebar.addSearchEngine) {
		window.sidebar.addSearchEngine(
			link.href.replace(/xml$/, 'src'),
			link.href.replace(/xml$/, 'gif'),
			link.firstChild.nodeValue,
			'Reference');
		return false;
	} else {
		return confirm("The plugin couldn't be installed automatically.  Display it instead?");
	}
}
