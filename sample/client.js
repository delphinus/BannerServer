;'use strict';

(function($){$(document).ready(function(){

$('[class^=lev_]').each(function(){
    var $this = $(this)
        ,clName = $.grep($this.attr('class').split('\s+'), function(i) {
            return /^lev_/.test(i);
        })[0]
        ,m = clName.match(/^lev_(\d+)_(\d+)$/)
    ;

    if (!m || m.length < 3) return;

    $.getJSON('http://img.remora.cx/get?callback=?', {
        w: m[1]
        ,h: m[2]
        ,ts: (new Date).getTime()
    }, function(data) {
        $this.html(data.content);
    });
});

});})(jQuery);
