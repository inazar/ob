path = require 'path'
express = require 'express'
bodyParser = require 'body-parser'
assets = require 'connect-assets'
crypto = require 'crypto'
xmlparser = require 'express-xml-bodyparser'
# jsPrimer = require 'connect-assets-jsprimer'

api =
  public: '12d8f0a1-bdeb-4e1f-847a-11bc438c782b'
  secret: '03d556ca-bda2-4748-bbcb-88b3769afaef'
  api: 'aebb70c9-ca7a-443c-b88d-27638b65e601'

product =
  description: 'Dummy product'
  tracking: '12345'

customer =
  id: 'dummy'
  email: 'test@example.com'

#### Basic application initialization
# Create app instance.
app = express()
transactions = Object.create(null)

# Define Port
port = process.env.PORT or process.env.VMC_APP_PORT or 8088

#### View initialization
app.use assets({})
# jsPrimer.loadFiles assets, console.log

# Set View Engine.
app.set 'view engine', 'jade'

# Set the public folder as static assets.
# app.use express.static('assets')

app.use xmlparser()
app.use bodyParser.urlencoded extended: false

app.get '/', (req, res) ->
  res.render 'index.jade',
    key: api.public
    query: req.query

app.get '/confirm', (req, res) -> res.redirect '/'

app.post '/confirm', (req, res) ->
  return res.redirect('/?error=No amount given') if not (amount = req.param('amount'))
  return res.redirect("/?error=Wrong amount: #{req.param('amount')}") if isNaN(amount = parseFloat amount) or amount <= 0
  amount = (Math.round(amount*100)/100).toFixed(2)
  now = new Date().toISOString()
  unique = crypto.createHash('md5').update(now).digest('hex').substr(0, 10)
  now = now.split('T')
  token = "#{now[0]} #{now[1].split('.')[0]} #{unique}"
  hash = crypto.createHash('sha256').update(token+api.secret+product.tracking+amount+'USD').digest('hex')
  res.render 'confirm.jade',
    amount: amount
    currency: 'USD'
    description: product.description
    tracking: product.tracking
    customer: customer.id
    email: customer.email
    key: api.public
    token: token
    hash: hash
    success: '/success'
    cancel: ''

app.get '/success', (req, res) -> res.render 'success.jade'

app.post '/postback', (req, res) ->
  console.log 'Postback query', req.query
  console.log 'Postback body', req.body
  console.log 'URL', req.url
  res.status(200).end()

app.listen port, ->
  console.log "OB Test is listening on %d in '%s' mode", port, process.env.NODE_ENV || 'development'
