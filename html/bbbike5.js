$("#autocomplete9").autocomplete({
	url:'search.php',
	values : true,
	writable : false,
	onSelect:function(){
		alert(this.pairs[this.ac.val()]);
	}
});
