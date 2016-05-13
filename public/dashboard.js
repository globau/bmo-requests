$(function() {
    'use strict';

    $.extend({
        escape: function(s) {
            return s === undefined
                ? ''
                : s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;');
        },
        ago: function(dt) {
            let ss = Math.round((new Date() - dt) / 1000);
            let mm = Math.round(ss / 60),
                hh = Math.round(mm / 60),
                dd = Math.round(hh / 24),
                mo = Math.round(dd / 30),
                yy = Math.round(mo / 12);
            if (ss < 10) return 'just now';
            if (ss < 45) return ss + ' seconds ago';
            if (ss < 90) return 'a minute ago';
            if (mm < 45) return mm + ' minutes ago';
            if (mm < 90) return 'an hour ago';
            if (hh < 24) return hh + ' hours ago';
            if (hh < 36) return 'a day ago';
            if (dd < 30) return dd + ' days ago';
            if (dd < 45) return 'a month ago';
            if (mo < 12) return mo + ' months ago';
            if (mo < 18) return 'a year ago';
            return yy + ' years ago';
        }
    });

    let fields = [
        {
            name: 'bug',
            render: function(item) {
                return $('<a/>')
                    .attr('href', 'https://bugzilla.mozilla.org/show_bug.cgi?id=' + item.bug_id)
                    .text(item.bug_desc);
            }
        },
        {
            name: 'flag',
            render: function(item) {
                return $.escape(item.flag_name);
            }
        },
        {
            name: 'requestor',
            render: function(item) {
                return $.escape(item.flag_who);
            }
        },
        {
            name: 'attachment',
            render: function(item) {
                if (!item.attach_id) {
                    return '-';
                }
                var url = 'https://bugzilla.mozilla.org/';
                if (item.attach_is_patch) {
                    url = url + 'page.cgi?id=splinter.html&bug=' + item.bug_id + '&attachment=' + item.attach_id;
                } else {
                    url = url + 'attachment.cgi?id=' + item.attach_id;
                }
                return item.attach_id
                    ? $('<a/>')
                        .attr('href', url)
                        .attr('target', '_blank')
                        .text(item.attach_desc)
                    : '-';
            }
        },
        {
            name: 'created',
            render: function(item) {
                return $.ago(new Date(item.flag_when * 1000));
            }
        },
    ];

    function update() {
        $('#loading').show();
        $.getJSON('get', function(data) {
            $('#loading').hide();
            if (data.error) {
                console.error(data.error);
                return;
            }
            document.title = 'bmo requests (' + data.flags.length + ')';

            let $container = $('#flags');
            $container.empty();

            let $table = $('<table/>').attr('id', 'grid');
            $container.append($table);

            let $tr = $('<tr/>').addClass('header');
            $.each(fields, function() {
                let field = this;
                $tr.append($('<th/>').addClass(field.name).text(field.name));
            });
            $table.append($tr);

            $.each(data.flags, function() {
                let item = this;
                let $tr = $('<tr/>');
                $.each(fields, function() {
                    let field = this;
                    $tr.append($('<td/>').addClass(field.name).append(field.render(item)));
                });
                $table.append($tr);
            });

            if (!data.flags.length) {
                $table.append(
                    $('<tr/>').append(
                        $('<td/>')
                            .attr('colspan', fields.length)
                            .attr('id', 'zarro')
                            .text('none')
                    )
                );
            }
        })
            .always(function() {
                $('#loading').hide();
            });
    }

    update();
    window.setInterval(update, 15 * 60 * 1000);
});
