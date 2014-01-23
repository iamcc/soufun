fs = require 'fs'
http = require 'http'
async = require 'async'
cheerio = require 'cheerio'
iconv = require 'iconv-lite'
BufferHelper = require 'bufferhelper'

keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
allCity = []
tasks = []

loadCity = (k, cb)->
  http.get {
    host: 'm.soufun.com'
    path: '/template/city/hotcity.jsp?key='+k
    headers:
      'user-agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.77 Safari/537.36'
  }, (res)->
    bufferHelper = new BufferHelper()
    bufferHelper.load res, (err, buffer)->
      $ = cheerio.load iconv.decode(buffer, 'GBK')
      $('.ablack').each (i, el)->
        code = el.attribs.href.replace('/', '').replace('.html', '')
        allCity.push {code: code, name: $(el).text()}
      cb()
      console.log 'loaded', k

for k in keys
  tasks.push (
    (arg)->
      (cb)->loadCity arg, cb
  )(k)

async.auto tasks, (err)->
  return console.log err if err
  for i in [1..10]
    new City(allCity.pop()).load()

City = (opts)->
  @name = opts.name
  @code = opts.code
  @page = 1
  @opts =
    host: 'm.soufun.com'
    path: '/xf.d?m=xflist&city='+@code+'&datatype=json'
    headers:
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.77 Safari/537.36'
      'Content-Type': 'application/x-www-form-urlencoded'
  @bufferHelper = new BufferHelper()
  fs.writeFileSync 'data/'+@name+'.xls', '<table>'#, (err)-> console.log err if err
City::log = (str)-> fs.appendFileSync 'data/'+@name+'.xls', str+'\r\n'#, (err)-> console.log err if err
City::load = ->
  self = @
  param = 'p='+@page
  @opts.headers['Content-Length'] = param.length
  @log '<tr><td>page-'+@page+'</td></tr>'
  req = http.request @opts, (res)->
    self.bufferHelper.load res, (err, buffer)->
      if err
        console.log err
        return self.load()
      hasData = false
      $ = cheerio.load iconv.decode(buffer, 'GBK')
      $('.houselist-txt').each (i, el)->
        tmp = '<tr>'
        items = $(el).text().split('\n').filter (str)-> str.trim()
        item = item.trim() for item in items
        tmp += "<td>#{item.trim()}</td>" for item in items
        tmp += '</tr>'
        self.log tmp
        hasData = true
      if hasData
        self.page++
        self.load()
        console.log 'loaded', self.name, self.page
      else
        self.log '</table>'
        city = allCity.pop()
        new City(city).load() if city
        console.log 'end', self.name
  req.write param
  req.end()