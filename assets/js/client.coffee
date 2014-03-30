$(document).ready ->

  # $(window).konami
  #     cheat: ->
  #       alert "C'est pas bien de diviser par zéro..."

  connect_url = "/"
  id_connexion= false
  last_msg_id = false

  socket = io.connect(connect_url)
  msg_template = $('#message-box').html()
  $('#message-box li').remove()

  user_box_template = $('#user_box').html()
  $('#user_box').remove()

  unless window.location.pathname=='/admin'
    #console.log('Envoi du Hello initial') 
    socket.emit('Hello')
    
  socket.on 'Olleh', (id) ->
    console.log('Olleh recu')
    id_connexion=id

  socket.on 'update_compteur', (connected) ->
    $('.nb-connected').html("<span>"+connected+"</span> auditeurs <br>en ligne</h2>")

  # log des users
  $('#loginform').submit( (e) ->
    e.preventDefault()
    socket.emit('login', {
      username: $('#username').val(),
      mail: $('#mail').val(),
      id_connexion: id_connexion
      })
    )

  socket.on 'erreur', (message) ->
    #console.log('Erreur recu')
    $('#wrong-mail').html(message).fadeIn()

        




  # gestion des utilisateurs
  socket.on 'newuser', (user) ->
    id_to_find = "\##{user.id}"
    if($('#members-list').find(id_to_find).length == 0)
      #html_to_append = "<img src=\"#{user.avatar}\" id=\"#{user.id}\">" 
      $('#members-list').append(Mustache.render(user_box_template,user))

  socket.on 'logged', ->
    $('#login').fadeOut()
    $('#message-form').fadeIn()
    $('#message-to-send').focus()

  socket.on 'disuser', (user) ->
    id_to_find = "\##{user.id}"
    $('#members-list').find(id_to_find).fadeOut()


  # envoi de message
  $('#message-form').submit (e) ->
    e.preventDefault()
    socket.emit 'nwmsg', {
      message: $('#message-to-send').val(),
      id_connexion: id_connexion
    }
    $('#message-to-send').val("")
    $('#message-to-send').focus()

  socket.on 'nwmsg', (message) ->
    flag_scrollauto=$('#messages').prop('scrollHeight')<=($('#main').prop('scrollTop')+$('#main').height())
    if last_msg_id != message.user.id
      $('#messages').append(Mustache.render(msg_template,message))
      last_msg_id = message.user.id
    else
      $(".message:last").append('<p>'+message.message+'</p>')
    if flag_scrollauto
      $('#main').animate({scrollTop: $('#messages').prop('scrollHeight')},500)


  $('#admin-form').submit( (e) ->
    e.preventDefault()
    #maj du titre
    if $('#episode-number').val()!='' && $('#episode-title').val()!=''
      socket.emit('change-title', {
        password: $('#admin-password').val(),
        number: $('#episode-number').val(),
        title: $('#episode-title').val()
        })
    else
      if $('#episode-number').val()
        alert "Titre de l'épisode non renseigné"
      else
        if $('#episode-title').val()
          alert "Numero de l'épisode non renseigné"
    )


  socket.on 'new-drawings', (livedraw_iframe) ->
    #console.log("nouvel iframe images")
    $('#live-draw-frame iframe').attr('src',livedraw_iframe)


  socket.on 'new-title', (episode) ->
    #console.log("Nouveau Titre")
    $('#title-episode').html(episode)


    
    
  socket.on 'disconnect',() ->
    #console.log("evt disconnect recu")
    if id_connexion
      $('#login').fadeIn()
      $('#message-form').fadeOut()
      console.log("Il s'est fait jeté")
      msg="Damned! Vous avez été deconnecté !"
      $('#wrong-mail').html(msg).fadeIn()
      $('#members-list li').remove()
      $('.nb-connected').html("")
      id_connexion=false
      socket.emit('Hello')



  $(window).on 'beforeunload', ->
    console.log("il s'est barré")
    undefined if socket.emit 'triggered-beforeunload'




