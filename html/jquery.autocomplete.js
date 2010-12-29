(function($) {

    /**
     * autor: CTAPbIu_MABP
     * email: ctapbiumabp@gmail.com
     * site: http://mabp.kiev.ua/content/2008/04/08/autocomplete/
     * license: MIT & GPL
     * last update: 14.09.2009
     * version: 1.3
     */

    var ac = function(c, o) {
        this.cache = {}; // main chache {mask:[text]}
        this.store = {}; // secondary cache {mask:strind}
        this.pairs = {}; // cache of values {text:value}
        this.init(c, o);
    };

    ac.prototype = {

        // html elements
        ac : null, // main input
        ul : null, // autocomplete list
        img : null, // image
        container : null, // outer div

        // timeouts
        close : null, // ac hide
        timeout : null, // ac search

        // system definitons
        chars : 0, // previous search string lenght

        // user definitons
        url : null, // url for ajax request
        source : null, // <select/>, [], {} jQuery
        minchar : 0, // minchars
        delay : 50, // for search
        fillin : false, // pre fill-in
        type : 'xml', // ajax data type
        width : 200, // width
        top : false, // position top/bottom
        writable : true, // writeable/selectable
        values : false, // store values
        partial : false,

        // events, please use 'self' instead of 'this'
        onSelect : function () {
        },
        onSetup : function () {
        },
        onKeyPress : function () {
        },
        onSuggest : function () {
        },
        onError : function () {
        },
        onSuccess : function () {
        },
        onDisplay : function () {
        },

        init : function (ac, options) {
            var self = $.extend(this, options);

            self.container = $('<div/>')
                .css({width:self.width})
                .addClass('ac_conteiner')
                .insertBefore(ac);
            self.ac = $(ac)
                .attr({autocomplete:'off'})
                .blur(function() {
                    clearTimeout(self.close);
                    self.close = setTimeout(function() {
                        self.ul.hide();
                    }, 300);
                }) // IE bug self.ul[.hide()] = undefined
                .css({width:self.width-22}) // 18 img + 2 margin + 2 border
                .addClass('ac_input')
                .appendTo(self.container);
            self.img = $('<div/>')
                .click(function() {
                    clearTimeout(self.close);
                    self.scroll();
                    self.ul.toggle();
                    self.ac.focus();
                })
                .addClass('ac_img')
                .appendTo(self.container);
            self.ul = $('<div/>')
                .addClass('ac_results')
                .appendTo(self.container)
                .click(function() {
                    self.select();
                    self.ac.focus();
                }).mousedown(function() {
                    setTimeout(function() {
	                clearTimeout(self.close);
	                self.ac.focus();
                    }, 50); // IE scroll bug
	        });

            $(window).bind('resize load', function() {
                var c = self.container;
                self.ul.css({
                    width:self.width,
                    top:(   self.top ?
                            c.offset().top - self.ul.height() - parseInt(c.css('border-top-width')) :
                            c.offset().top + c.height() + parseInt(c.css('border-bottom-width')) ),
                    left:(c.offset().left + parseInt(c.css('border-left-width')))
                });
            });

            if ($.browser.mozilla)
                self.ac.bind('keypress', self, self.process);
            else
                self.ac.bind('keydown', self, self.process);

            self.onSetup.apply(self,arguments);

            if (self.fillin)
                self.suggest('hide');
        },

        process : function (e) {
            var self = e.data, len = self.ac.val().length;
            self.onKeyPress.apply(self,arguments);

            if (/^(27|38|40|13|9)$/.test(e.keyCode) && self.ul.is(':visible')) {
                switch (e.keyCode) {
                    case 27: // escape
                        self.ul.hide();
                        break;
                    case 38: // up
                        self.prev();
                        break;
                    case 40: // down
                        self.next();
                        break;
                    case 13: // return
                    	e.preventDefault();
                    case 9:  // tab
                        self.select();
                        break;
                }
            } else if (!/^9$/.test(e.keyCode) && (len != self.chars || !len)) {
                self.chars = len;
                if (self.timeout)
                    clearTimeout(self.timeout);
                self.timeout = setTimeout(function() {
                    self.suggest('show');
                }, self.delay);
            }
        },

        get : function() {
            var self = this;
            return self.ul.children('.ac_over');
        },

        prev : function () {
            var self = this, current = self.get(), prev = current.prev();
            if (current.length) {
                current.removeClass('ac_over');
                if (prev.length)
                    prev.addClass('ac_over');
                }
            if (!current.length || !prev.length){
                self.ul.children(':last').addClass('ac_over');
            }
            self.scroll();
        },

        next : function () {
            var self = this, current = self.get(), next = current.next();
            if (current.length) {
                current.removeClass('ac_over');
                if (next.length)
                    next.addClass('ac_over');
            }
            if (!current.length || !next.length)
                self.ul.children(':first').addClass('ac_over');
            self.scroll();
        },

        scroll : function(){
            var self = this, current = self.get();
            if (!current.length)
                return; // quick return
            var el = current.get(0), list = self.ul.get(0); // dont scroll after click on document :(
            if(el.offsetTop + el.offsetHeight > list.scrollTop + list.clientHeight)
                list.scrollTop = el.offsetTop + el.offsetHeight - list.clientHeight;
            else if(el.offsetTop < list.scrollTop)
                list.scrollTop = el.offsetTop;
        },

        select : function () {
            var self = this, current = self.get();
            if (current) {
                self.ac.val(current.text());
                self.ul.hide();
                self.onSelect.apply(self,arguments);
            }
        },

        suggest : function (show) {
            var self = this, mask = $.trim(self.ac.val());
            self.ul.hide();
            
            if (mask.length >= self.minchar) {
                self.onSuggest.apply(self,arguments);
                if (self.check(mask) && !$.isFunction(self.url))
                    self.prepare(self.grab(mask),mask)[show]();
                else if (self.url) // use ajax
                    $.ajax({type: "GET", data:{mask:mask},
                        url:$.isFunction(self.url)?self.url(self):self.url,
                        success:function(xml) {
                            self.onSuccess.apply(self,arguments);
                            self.prepare(xml,mask)[show]();
                        },
                        error:function(){
                            self.onError.apply(self,arguments);
                        },
                        dataType:self.type
                    });
                else if (self.source) // use source
                    self.prepare(self.source,mask)[show]();
            }else{
                self.ul.empty();
            }
        },

        check: function (mask){
            var self = this;
            if (self.cache[mask])
                return true; // quick return
            if(self.partial)
                return false;
            mask = mask.toLowerCase();
            for(var it in self.cache)
                if (it && !mask.indexOf(it.toLowerCase()))
                    return true;
            return false;
        },

        grab: function (mask){
            var self = this, map = [], array = [];
            if (self.cache[mask])
                return self.cache[mask]; // quick return
            for(var it in self.cache)
                array.push(it);
            array = array.reverse();
            mask = mask.toLowerCase();
            for(var item in array)
                if(!mask.indexOf(array[item].toLowerCase())){
                    for(var word in self.cache[array[item]])
                        if (!self.cache[array[item]][word].toLowerCase().indexOf(mask))
                            map.push(self.cache[array[item]][word]);
                    break;
                }
            return map;
        },

        prepare : function(xml, mask){
            var self = this, select = $(xml);
            self.store[mask] = '';
            self.cache[mask] = [];
            if (!self.store[mask]){
                if(select.context) // use selectbox or ajax result
                    select.find("option").each(function(i, n) {
                        var t = $(n).text();
                        self.cache[mask].push(t);
                        self.store[mask] += self.mark(t,mask);
                        if(self.values && !self.pairs[t]){
                            self.pairs[t] = $(n).attr("value");
                        }
                    });
                else // use array or array-like object
                    $.each(xml, self.dataHandler(mask));
            }

            if (!self.writable && !self.cache[mask].length){
                setTimeout(function(){
                    var val = self.ac.val();
                    self.ac.val(val.substring(0, val.length-1));
                    self.chars--;
                },50);
                return self.ul;
            }
            return self.display(self.store[mask]);
        },
        
        dataHandler : function(mask){
            var self = this;
            return function(i, n) {
                self.cache[mask].push(n);
                self.store[mask] += self.mark(n,mask);
                if(self.values && !self.pairs[n])
                    self.pairs[n] = i;
                };
        },

        mark : function(text, mask){
            return new RegExp('^' + mask, 'ig').test(text) ?
                '<div>' + text.replace(new RegExp('^' + mask, 'ig'), function(mask) {
                    return '<span class="ac_match">' + mask + '</span>';
                }) + '</div>' : '';
        },

        display : function (list) {
            var self = this;
            self.onDisplay.apply(self,arguments);
            if (!list)
                return self.ul.empty().end().end(); // fake
            return self.ul.html(list).children('div').mouseover(function() {
                    $(this).siblings().removeClass('ac_over').end().addClass('ac_over');
                }).eq(0).addClass('ac_over').end().end(); // ul
        }
    };

    $.fn.autocomplete = function(options) {
        this.each(function() {
            if (this.tagName == 'SELECT' && !this.multiple) {
                var select = $(this),
                    input = $("<input type='text'/>")
                        .addClass(select.attr('class'))
                        .attr('tabindex', select.attr('tabindex'))
                	.attr('id', 'ac_' + select.attr('id'));
                	
                select.after(input).hide(); // add text input and hide the select
                
                $("label[for='"+select.attr('id')+"']")
                    .attr('for', 'ac_' + select.attr('id'));
                
                new ac(input, $.extend({
                    source: this,
                    values: true,
                    fillin: true,
                    writable : false,
                    onSelect: function() {
                        select.val(this.pairs[this.ac.val()]);
                    }
                }, options));
            } else if (this.tagName == 'INPUT'){
                new ac(this, options);
            }
        });
        return this;
    };

})(jQuery);