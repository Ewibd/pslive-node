
require('coffee-script')
express = require('express')
routes = require('./routes')
user = require('./routes/user')
http = require('http')
https = require('https')
path = require('path')
md5 = require('MD5')
mu = require('mu2')
cheerio = require('cheerio')
url_parser = require('url')
validator = require('validator')
Twitter = require('./twitter');
Backend = require('./backend_interface');
fs = require('fs')
mime = require('mime')
app = express()












#all environments
app.use require('connect-assets')()
console.log js('client')
app.set('port', process.env.PORT || 3001)
app.set('views', __dirname + '/views')
app.set('view engine', 'jade')
app.use(express.favicon("/images/fav.png"))
app.use(express.logger('dev'))
app.use(express.bodyParser())
app.use(express.methodOverride())
app.use(app.router)
app.use(express.static(path.join(__dirname, 'public')))
app.locals.css = css
app.locals.js = js
#development only
if ('development' == app.get('env'))
  app.use(express.errorHandler())








#router
app.get('/', routes.index)
app.get('/admin', routes.admin)
app.get('/users', user.list)
app.get '/messages', (req, res) ->
  res.send all_messages.map((message) -> "<b>#{message.user.username}:</b> #{message.message}").join("<br/>")
app.get '/timestamp', (req, res) ->
  res.send all_messages.map((message) -> 
    "<b>#{message.user.username}</b> [#{(message.h+2)%24}:#{message.m}:#{message.s}]: <span id='[#{(message.h+2)%24}:#{message.m}:#{message.s}]'>#{message.message}</span>"
  ).join("<br/>")
app.get '/questions', (req, res) ->
  res.send all_messages.filter( (msg,idx) -> 
    if typeof(msg)!='undefined' && typeof(msg.message)!='undefined'
      msg.message.indexOf("@ps")>-1 || msg.message.indexOf("@PS")>-1
    else
      false
  ).map((message) -> 
    "<b>#{message.user.username}</b><a href='/timestamp#[#{(message.h+2)%24}:#{message.m}:#{message.s}]'>[#{(message.h+2)%24}:#{message.m}:#{message.s}]</a>: #{message.message}"
  ).join("<br/>");

httpServer = http.createServer(app).listen(app.get('port'), ->
  console.log('Express server listening on port ' + app.get('port'))
)





#socket.io configuration
io = require('socket.io').listen(httpServer)
io.configure ->
  io.set("transports", ['websocket','flashsocket','htmlfile','xhr-polling','jsonp-polling'])
  #io.set("polling duration", 100)
  #io.set('close timeout', 200)
  io.set('heartbeat timeout', 200)
  # io.set('log colors',false)
  io.set('log level',0)







#Initialisation des variables
users = new Object()

auth_twitter = {
    consumer_key:         process.env.PSLIVE_TWITTER_CONSUMERKEY,
    consumer_secret:      process.env.PSLIVE_TWITTER_CONSUMERSECRET,
    access_token_key:     process.env.PSLIVE_TWITTER_TOKENKEY,
    access_token_secret:  process.env.PSLIVE_TWITTER_TOKENSECRET
}
console.log auth_twitter
twitter = new Twitter(auth_twitter)

backend = new Backend({ 
    url:  (process.env.PSLIVE_BACKEND_URL || 'localhost') ,
    port: (process.env.PSLIVE_BACKEND_PORT || 3000)
  })

last_messages   = []
all_messages    = []
liste_images    = []
history         = 10
nomEvent        = ''
admin_password  = process.env.PSLIVE_ADMIN_PASSWORD
episode         = 'Bienvenue sur le balado qui fait aimer la science!'




###############################
####  functions ###############
###############################

#simple
replaceURLWithHTMLLinks = (text) -> 
  exp = /(\b(https?|ftp|file):\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|])/ig
  return text.replace(exp,"<a href='$1' target='_blank'>$1</a>")


insertChatroomImages = (text,user,avatar) -> 
  exp = /https?:\/\/[-A-Z0-9+&@#\/%?=~_|!:,.;]*[-A-Z0-9+&@#\/%=~_|]/i
  console.log text
  if tab_url = text.match(exp)
    console.log tab_url
    tab_url.map (url)->
      get_image url, (nom,data,content_type)->
        if(content_type == 'image/jpeg' || content_type == 'image/gif' || content_type == 'image/png' )
          param_img={
            'nom' : nom, 
            'poster':user,
            'poster_user':user,
            'avatar':avatar,
            'tweet':replaceURLWithHTMLLinks text
            'media_type' : 'img'
          }
          for idx,i of liste_images
            if i.nom==nom
              console.log "image deja presente"
              return false
          backend.upload_image nomEvent, nom, user,user,avatar, text, data, (url_wp)->  
            console.log "image uploadée"
            param_img.url=url_wp
            console.log param_img
            liste_images.push param_img 
            io.sockets.emit 'add_img',param_img
            console.log 'media:'+ nom



replaceSalaud = (text) ->
  exp=/salaud/ig
  retval=text.replace(exp,"salop\*")
  if (text!=retval)
    retval=retval+"<br><span style='font-weight:lighter;font-size:x-small;'>*Correction apportée selon la volonté du DictaTupe.</span>"
  return retval



#fonction pour compter (.length ne marche pas.... a voir)
compte = (tab)->
  cpt=0
  for key,elt of tab
    cpt=cpt+1
  return cpt      
  
pad2 = (val) ->
  if (val<10)
    return  '0'+val
  else
    return val
  
#------------------------------------
#Fonction pour la gestion des images
get_image = (url,cb) ->
  nom=url.slice url.lastIndexOf('/')+1
  exp = /https:\/\//i
  if url.match(exp)
    proto=https 
  else
    proto=http
  console.log "chargement images en RAM : ",url
  proto.get url, (response)->
      content_type=response.headers['content-type']
      data=''
      if !(content_type == 'image/jpeg' || content_type == 'image/gif' || content_type == 'image/png' )
        cb nom,data,content_type
      response.setEncoding('binary')
      console.log "reception d'une reponse",response
      response.on 'data',
        (chunk)->data+=chunk
        console.log "data"
      response.on 'end',()->
        console.log "Fin du chargement de "+nom+":"
        cb nom,data,content_type


get_image_twitter = (url,cb) ->
  nom=url.slice url.lastIndexOf('/')+1
  console.log "chargement images en RAM : ",url
  http.get url+':large', (response)->
      data=''
      response.setEncoding('binary')
      console.log "reception d'une reponse"
      response.on 'data',
        (chunk)->data+=chunk
        console.log "data"
      response.on 'end',()->
        console.log "Fin du chargement de "+nom+":"
        cb nom,data


get_thumbnail = (site,url,cb) ->
  if site=='vine.co'
    console.log "chargement du thumbnail Vine",url
    https.get url.replace('http://','https://'), (response)->
      data=''
      response.on 'data',(chunk)->
        data+=chunk
      response.on 'end',()->
        console.log "pages chargee",data
        $ = cheerio.load(data)
        cb $('meta[property="twitter:image"]').attr('content')      
  else
    cb ""

 

liste_connex    = []
  
load_episode = (number,title,chatroom) =>
    console.log "*********************************************************"
    all_messages  = (chatroom || [])
    last_messages = []
    for msg in all_messages
      last_messages.push msg
      last_messages.shift() if (last_messages.length > history)
    nomEvent = number
    if nomEvent == 'podcastscience'
      episode=title
    else
      episode= "<span class='number'> Episode #"+number+" - </span> "+title
    backend.download_images (meta)->      
      liste_images=meta
    twitter.stream {track: '#'+nomEvent} 

console.log backend

backend.get_default_emission( load_episode )




send_chatroom = (socket_) ->
  console.log("envoi de l'historique")
  if nomEvent != 'podcastscience'
    for message in last_messages
      console.log message
      socket_.emit('nwmsg',message)
    for im in liste_images
      console.log im
      site = im.url.split('/')[0]
      get_thumbnail site,'https://'+im.url,(url_thumbnail) ->
        im.url_thumbnail=url_thumbnail
        socket_.emit('add_img',im) 
  console.log episode
  socket_.emit('new-title',episode)

change_chatroom = () ->
  io.sockets.emit 'del_imglist'
  io.sockets.emit 'del_msglist'
  send_chatroom io.sockets



io.sockets.on 'connection', (socket) ->
  console.log "Nouvelle connexion... ("+io.sockets.clients().length+" sockets)"



  #connexion a la page de live. L'utilisateur n'est pas connecté.
  #Les valeurs sont donc initialisées pour cela
  me = false
  id_connexion= false
  cpt_message=0
  id_last_message=""

  envoieInitialChatroom = () ->
    #Envoi des messages récents au client
  
    send_chatroom socket


  # gestion de la connexion au live. Le client evoi un Hello au serveur
  # qui lui reponf Olleh avec un id qui permettra de au serveur de s'assurer
  # que le client est connu (notamment compté)
  socket.on 'Hello', (id_demande) ->
    #calcul de l'id
    if(id_demande=='')
      console.log("generation de l'id")
      id_connexion = md5(Date.now())
    else
      id_connexion = id_demande
    liste_connex[id_connexion]=''
    
    #envoi de Olleh
    console.log('Hello recu. Envoi du Olleh : '+id_connexion)
    socket.emit('Olleh',id_connexion)
    if(id_demande=='')
      envoieInitialChatroom()
    #mise a jour du compteur et de la userlist pour tous les connectés
    io.sockets.emit('update_compteur',{
      connecte:compte(users),
      cache:compte(liste_connex)-compte(users)
    })
    console.log('Ouverture de la connexion '+id_connexion+'. '+compte(liste_connex)+' connexions ouvertes')
    for key, value of users
      console.log('Ajout du user '+value.mail)
      socket.emit('newuser',value)
    
    
    
    
    
  #Login : l'utilisateurs se connecte a la Chatroom
  socket.on 'login', (user) ->
    #Verification si le client est connu. dans le cas contraire, on le deconnecte
    verif_connexion(user.id_connexion)
        
    #Verification de la validité de l'identification
    unless  validator.isEmail(user.mail)
      socket.emit('erreur',"Email invalide")
      return -1
    unless validator.isLength(user.username,3,30)
      socket.emit('erreur',"Le nom d'utilisateur doit être compris entre 3 et 30 lettres")
      return -1

    try

      # Verification de l'existance de l'utilisateur
      # Le cas échéant, on incremente un compteur
      for key, existing_user of users
        #console.log 'Verif '+existing_user.mail+'/'+existing_user.username
        if (user.mail == existing_user.mail) && (user.mail!='')
          me = existing_user
          console.log '\tuser already exist!'
          me.cpt += 1
          console.log '\tcpt '+me.mail+':'+me.cpt

      #dans le cas contraire, on le créé dans la userlist
      unless me
        me = user
        #me.id = user.mail.replace('@','-').replace(/\./gi, "-")
        me.id = Date.now()
        me.cpt=1
        console.log 'cpt '+me.mail+':'+me.cpt
        me.avatar = 'https://gravatar.com/avatar/' + md5(user.mail) + '?s=40'
        users[me.id] = me
        #on informe tout le monde qu'un nouvel utilisateur s'est connecté
        io.sockets.emit('newuser',me)
        
        io.sockets.emit('update_compteur',{
          connecte:compte(users),
          cache:compte(liste_connex)-compte(users)
        })
      #on informe l'utilisateur qu'il est bien cnnecté
      socket.emit('logged')

  
        
      


  #Verification de la connection
  verif_connexion=(id_connexion_loc)->
    console.log("Verif si la connexion "+id_connexion_loc+" existe")
    for key, val of liste_connex
      if (key == id_connexion_loc)
        return true
    #Si ce n'est pas le cas, on le deconnecte.
    #Sa reaction sera normalement de se reconnecter proprement immediatement
    console.log("Une connexion inconnu a été repérée")
    socket.emit('disconnect',"Utilisateur inconnu")
    return false



  #Serie de fonctions gérant la deconnexion
  deconnexion=() ->
    #On supprime la connexion de la liste
    console.log('Suppression de la connexion '+id_connexion)
    delete liste_connex[id_connexion]
    #on met a jour le compteur des autres users
    io.sockets.emit('update_compteur',{
      connecte:compte(users),
      cache:compte(liste_connex)-compte(users)
    })
    console.log("Nombre d'utilisateurs : "+compte(liste_connex))
    #si le une connexion a la chatroom existe, on le delg
    unless me == false
      logout()
    

  #gestion de la deconnexion de la chatroom
  logout=() ->
    #on decremente le compteur de cnx du l'utilisateur
    me.cpt -= 1
    console.log 'cpt '+me.mail+':'+me.cpt
    unless(me.cpt > 0)
      #si le compteur arrive a 0, on le supprime de la userlist
      #et on en informe les autres clients
      delete users[me.id]
      io.sockets.emit('disuser',me)
      io.sockets.emit('update_compteur',{
        connecte:compte(users),
        cache:compte(liste_connex)-compte(users)
      })



  socket.on 'disconnect', ->
    #gestion de la coupure de connexion du client
    console.log 'Deconnexion de '+me.name
    if verif_connexion(id_connexion)
      deconnexion()



  # gestion des messages
  socket.on 'nwmsg', (message) ->
    if verif_connexion(message.id_connexion)
      cpt_message+=1
      message.user = me
      date = new Date()
      insertChatroomImages message.message , message.user.username ,message.user.avatar
      message.message = replaceURLWithHTMLLinks(validator.escape(message.message))
      message.message = replaceSalaud(message.message)
      id_last_message = md5(Date.now()+cpt_message+message.user.mail)
      message.id = id_last_message
      message.h = pad2(date.getHours())
      message.m = pad2(date.getMinutes())
      message.s = pad2(date.getSeconds()) 
      console.log message
      all_messages.push message
      last_messages.push message
      last_messages.shift() if (last_messages.length > history)
      io.sockets.emit('nwmsg',message)
      backend.set_chatroom JSON.stringify(all_messages)
   
    
  socket.on 'editmsg', (message) -> 
    console.log("demande de modif de message : "+message.message)
    if verif_connexion(message.id_connexion)
      message.message = replaceURLWithHTMLLinks(validator.escape(message.message))
      message.message = replaceSalaud(message.message)
      message.id = id_last_message
      io.sockets.emit('editmsg',message)
      for key,elt of all_messages
        elt.message = message.message if elt.id == id_last_message
      for key,elt of last_messages
        elt.message = message.message if elt.id == id_last_message
      backend.set_chatroom JSON.stringify(all_messages)
    
  #GESTION DE L'admin (qui n'envoi pas de HELLO)
            


  # Changement du titre et chargement de l'iframe
  socket.on 'change-title', (message) ->
    nomEvent= 'ps' +message.number
    if message.password == admin_password   
      episode= "<span class='number'> Episode #"+(message.number)+" - </span> "+message.title
      backend.select_emission(nomEvent,message.title, (res) -> 
        console.log res
        all_messages  = (res || [])
        last_messages = []
        for msg in all_messages
          last_messages.push msg
          last_messages.shift() if (last_messages.length > history)
        backend.download_images (meta)->      
          liste_images=meta
          change_chatroom()
      )
      try
        twitter.destroy()
      try
        twitter.stream {track: '#'+nomEvent} 
      catch e
        console.log "erreur Twitter",e
    else
        socket.emit 'AuthFailed'
        
 


  # Reitinialisation de la chatroom
#                
  socket.on 'reinit_chatroom', (password) ->
    console.log("Reinitiailisation de la chatroom")
    episode='Bienvenue sur le balado qui fait aimer la science!'
    nomEvent = "podcastscience"
    backend.select_emission(nomEvent,episode, (res) -> 
        console.log res
        last_messages = []  
        all_messages = []
        backend.download_images (meta)->
          liste_images=meta
          change_chatroom()
      )
    try
      twitter.destroy()






init_twitter = (twitter) ->
  twitter.on 'data', (data) -> 
    console.log "reception : ",data
    console.log "url : ", data.entities.urls
    try
      url         = data.entities.media[0].media_url
      poster      = data.user.name
      poster_user = data.user.screen_name
      avatar      = data.user.profile_image_url
      tweet       = data.text
      media_type  = 'img'
    catch e
      try
        site = data.entities.urls[0].display_url.split('/')[0]
        if site=='vimeo.com' || site=='youtube.com'  || site=='vine.co' 
          url         = data.entities.urls[0].display_url
          poster      = data.user.name
          poster_user = data.user.screen_name
          avatar      = data.user.profile_image_url
          tweet       = data.text
          media_type  = 'video'
      catch e
    return 0 if (url==null) || (typeof(url) == 'undefined')

    if media_type == 'img'
      get_image_twitter url, (nom,data)->
        param_img={
          'nom' : nom, 
          'poster':poster,
          'poster_user':poster_user,
          'avatar':avatar,
          'tweet':replaceURLWithHTMLLinks tweet
          'media_type' : media_type
        }
        for idx,i of liste_images
          if i.nom==nom
            console.log "image deja presente"
            return false
        backend.upload_image nomEvent, nom, poster,poster_user,avatar, tweet, data, (url_wp)->  
          console.log "image uploadée"
          param_img.url=url_wp
          console.log param_img
          liste_images.push param_img 
          io.sockets.emit 'add_img',param_img
          console.log 'media:'+ nom
    if media_type == 'video'
      url_o = url_parser.parse data.entities.urls[0].expanded_url ,  true , true
      switch site
        when 'youtube.com' then nom = url_o.query.v
        when 'vimeo.com' then nom = url_o.pathname.split('/')[..].pop()
        when 'vine.co' then nom = url_o.pathname.split('/')[..].pop()
        else return false
      console.log   '1',url_o
      console.log   '2',url_o.query
      param_img={
        'nom' : nom, 
        'poster':poster,
        'poster_user':poster_user,
        'avatar':avatar,
        'tweet':replaceURLWithHTMLLinks tweet
        'media_type' : media_type
      }
      for idx,i of liste_images
        if i.nom==nom
          console.log "video deja presente"
          return false
      get_thumbnail  site,  data.entities.urls[0].expanded_url , (url_thumbnail)->
        param_img.url_thumbnail=url_thumbnail
        backend.upload_video nomEvent, nom, poster,poster_user,avatar, tweet, url, (url_wp)->  
        param_img.url=url
        param_img.site = site
        console.log param_img
        liste_images.push param_img 
        io.sockets.emit 'add_img',param_img
        console.log 'media:'+ nom


  twitter.on 'start', () -> 
    io.sockets.emit "twitter_start"


  twitter.on 'error', (data) -> 
    io.sockets.emit "errorTwitter",data


  twitter.on 'heartbeat', (data) -> 
    console.log  "Twitter stream is alive"
    io.sockets.emit 'heartbeat_twitter'

  twitter.on 'close', (data) -> 
    console.log  "Twitter stream is closed :",data
    io.sockets.emit 'twitter_close'
    twitter = new Twitter(auth_twitter) 
    init_twitter twitter



init_twitter twitter