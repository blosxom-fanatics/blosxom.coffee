#!/usr/bin/env coffee
# vim:set ft=coffee:
# CoffeeScript sucks.

fs = require 'fs'
path = require 'path'

class Blosxom
    constructor: (@config) ->

    run: ->
        entries = @getEntries().sort (a, b) -> b.datetime - b.datetime
        [_, path_info, flavour] = (process.env['PATH_INFO'] || '/').match(/(.+?)(\.[^.]+)?$/)
        flavour ||= @config.default_flavour

        if m = path_info.match(/// ^/(\d{4})(?:/(\d\d)(?:/(\d\d))?)? ///)
            [_, year, month, date] = m
            entries = entries.filter (i) ->
                [
                    { m: "getFullYear", v: +year },
                    { m: "getMonth", v: +month - 1 },
                    { m: "getDate", v: +date },
                ].every (r) ->
                    (isNaN(r.v) || i.datetime[r.m]() == r.v)
        else
            try
                entries = entries.filter (i) ->
                    if i.name == path_info then throw { permalink: true, entry: i }
                    i.name.indexOf(path_info) == 0
            catch error
                if !error.permalink then throw error
                entries = [ error.entry ]

        ret = @tmpl(fs.readFileSync("template#{flavour}", "utf-8"), {
            title       : @config.title,
            author      : @config.author,
            home        : process.env["SCRIPT_NAME"] || '/',
            path        : (process.env["SCRIPT_NAME"] || '/').split("/").slice(-1)[0],
            server_root : "http://" + process.env["SERVER_NAME"],
            entries     : entries,
        })

        console.log ret

    getEntries: ->
        getFiles = (files, dirs...) ->
            if dirs.length
                dir = dirs.pop()
                for _, file of fs.readdirSync(dir)
                    file = path.join(dir, file)
                    if fs.statSync(file).isDirectory()
                        dirs.push(file)
                    else
                        files.push(file) if file.match /\.txt$/
                getFiles(files, dirs...)
            else
                files


        for _, file of getFiles([], @config.data_dir)
            [title, body...] = fs.readFileSync(file, 'utf-8').split(/\n/)

            {
                file : file,
                name : String(file).replace(RegExp("^"+@config.data_dir+"|\\..*$", "g"), ""),
                datetime : fs.statSync(file).mtime,
                title: title,
                body : body.join("\n")
            }

    # Simple JavaScript Templating
    # John Resig - http://ejohn.org/ - MIT Licensed
    # Modified: escape all, append raw syntax and ported to coffeescript
    tmpl: (str, data) ->
        new Function("obj",
            """
            var p=[],print=function(){p.push.apply(p,arguments);};
            with(obj){p.push('#{str
                .replace(/\n/g, "\\x0a")
                .replace(/[\r\t]/g, " ")
                .split("<%").join("\t")
                .replace(/((^|%>)[^\t]*)'/g, "$1\r")
                .replace(/\t===(.*?)%>/g, "',String($1),'")
                .replace(/\t=(.*?)%>/g, "',String($1).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&#34;').replace(/\'/g,'&#39;'),'")
                .split("\t").join("');")
                .split("%>").join("p.push('")
                .split("\r").join("\\'")
            }');}return p.join('');
            """
        )(data)

new Blosxom({
    title           : "Blosxom.coffee",
    data_dir        : "data",
    default_flavour : ".html",
}).run()

