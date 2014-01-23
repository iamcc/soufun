fs = require 'fs'
http = require 'http'
async = require 'async'
cheerio = require 'cheerio'
iconv = require 'iconv-lite'
BufferHelper = require 'bufferhelper'

keys = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')
allCity = []
tasks = []
running = {}


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

City = (opts)->
  @name = opts.name
  @code = opts.code
  @page = opts.page or 1
  @opts =
    host: 'm.soufun.com'
    path: '/xf.d?m=xflist&city='+@code+'&datatype=json'
    headers:
      'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/32.0.1700.77 Safari/537.36'
      'Content-Type': 'application/x-www-form-urlencoded'
  @bufferHelper = new BufferHelper()
  fs.writeFileSync 'data/'+@name+'.xls', '<table>' if @page is 1
City::log = (str)-> fs.appendFileSync 'data/'+@name+'.xls', str+'\r\n'
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
        console.log 'loaded', self.name, self.page
        running[self.code] =
          code: self.code
          name: self.name
          page: self.page
        self.page++
        self.load()
      else
        self.log '</table>'
        city = allCity.pop()
        delete running[self.code]
        running[city.code] = city
        new City(city).load() if city
        console.log 'end', self.name
  req.on 'error', (err)->
    console.log err
    self.load()
  req.write param
  req.end()



try
  allCity = JSON.parse fs.readFileSync('allCity').toString()
  running = JSON.parse fs.readFileSync('running').toString()
  for code, city of running
    new City(city).load()
catch e
  console.log e
  for k in keys
    tasks.push (
      (arg)->
        (cb)->loadCity arg, cb
    )(k)
  async.auto tasks, (err)->
    return console.log err if err
    fs.writeFileSync 'allCity', JSON.stringify(allCity)
    for i in [1..10]
      city = allCity.pop()
      running[city.code] = city
      new City(city).load()

setInterval ->
  fs.writeFileSync 'running', JSON.stringify(running)
, 1000