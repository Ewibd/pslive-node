http = require('http')
mime = require('mime')

class Backend


	constructor: (params) ->
		@url = params.url 
		@port = params.port
		@id_emission = params.id_emission


	http_request_callback = (res,cb) ->
		str=""
		res.on 'data',  (chunk) ->
			str += chunk
		res.on 'end',  () ->
			try 
				data_JSON = JSON.parse(str)
			catch e
				console.log  "JSON invalide",e
				console.log str
			cb data_JSON 
	


	get_default_emission: (cb) ->
		headers = {
			'Content-Type': 'application/json'
		}
		options = {
			host: @url,
			port: @port,
			path: '/episodes_default.json',
			method: 'get',
			headers: headers
		}
		req = http.request options, (res)=> 
			http_request_callback res, (data)=>
				try
					@id_emission=data.id 
					try 
						chatroom = JSON.parse(data.chatroom)
					catch e
						console.log  "Erreur du parsing de la chatroom",e
					cb(data.number,data.title,chatroom)
				catch e
					@id_emission = 0
					cb(0,"Bienvenue sur le balado qui fait aimer la science!",{})
		req.on 'error',(err)->console.log Error
		req.end()


	upload_image: (episode,nom,auteur,user,avatar,message,data,cb) ->
		console.log "Entrée dans upload_image"
		try
			databin64 = new Buffer(data, 'binary').toString('base64') 
			params = JSON.stringify({
				'name': nom, 
				'msg': message,
				'author': auteur,
				'user': user,
				'avatar': avatar,
				'image': databin64,
				'content_type': mime.lookup(nom),
				'id_episode': @id_emission
			})
			console.log "upload d'une image : ",params.name
			headers = {
				'Content-Type': 'application/json',
				'Content-Length':  Buffer.byteLength(params, 'utf-8')
			}
			options = {
				host: @url,
				port: @port,
				path: '/upload_api.json',
				method: 'post',
				form: params,
				headers: headers
			}
			req = http.request options, (res)-> 
				try
					http_request_callback res, (data)=>
						try
							cb data.url
						catch e
							console.log "cb", e
						
						
				catch e
					console.log "req:",e
				
			req.on 'error', (err)->console.log err
			req.write params  
			req.end()
		catch e
			console.log "Erreur upload",e


	upload_video: (episode,nom,auteur,user,avatar,message,url,cb) ->
		console.log "Entrée dans upload_video"
		try
			params = JSON.stringify({
				'name': nom, 
				'msg': message,
				'author': auteur,
				'user': user,
				'avatar': avatar,
				'url': url,
				'id_episode': @id_emission
			})
			console.log "envoi d'une video : ",params.name
			headers = {
				'Content-Type': 'application/json',
				'Content-Length':  Buffer.byteLength(params, 'utf-8')
			}
			options = {
				host: @url,
				port: @port,
				path: '/add_video.json',
				method: 'post',
				form: params,
				headers: headers
			}
			req = http.request options, (res)-> 
				try
					http_request_callback res, (data)=>
						try
							cb data.url
						catch e
							console.log "cb", e
						
						
				catch e
					console.log "req:",e
				
			req.on 'error', (err)->console.log err
			req.write params  
			req.end()
		catch e
			console.log "Erreur upload",e


	download_images: (cb) ->
		headers = {
			'Content-Type': 'application/json'
		}
		options = {
			host: @url,
			port: @port,
			path: '/episodes/' + @id_emission + '/images.json',
			method: 'get',
			headers: headers
		}
		console.log "download des images : ", @id_emission
		req = http.request options, (res)-> 
			http_request_callback res, (data)->
				console.log data
				meta_tmp=[]
				try
					data.map (image)->
						if image.media_type == 'img'
							img = {
								'nom' : image.name, 
								'url' : image.url,
								'poster' : image.author,
								'poster_user' : image.user,
								'avatar' : image.avatar,
								'tweet' : image.msg
								'media_type' : 'img'
							}
						if image.media_type == 'video'
							img = {
								'nom' : image.name, 
								'url' : image.url,
								'poster' : image.author,
								'poster_user' : image.user,
								'avatar' : image.avatar,
								'tweet' : image.msg
								'media_type' : 'video'
							}
						meta_tmp.push img
						console.log img.url
				catch e
					console.log "pas d'image"
				console.log meta_tmp
				cb meta_tmp
		req.on 'error',(err)->console.log err
		req.end()


	select_emission: (nomEvent,episode,cb) ->
		console.log "entrée dans la fonction select_emission"
		params = JSON.stringify({
			number: nomEvent, 
			title: episode
		})
		console.log "*"+params+"*"
		console.log params.length
		headers = {
			'Content-Type': 'application/json'
			'Content-Length':  Buffer.byteLength(params, 'utf-8')
		}
		options = {
			host: @url,
			port: @port,
			path: '/episodes.json',
			method: 'post',
			form: params,
			headers: headers
		}
		req = http.request options, (res)=>
			http_request_callback res, (data)=>
				@id_emission=data.id	
				try 
					chatroom = JSON.parse(data.chatroom)
				catch e
					console.log  "Erreur du parsing de la chatroom",e
				cb chatroom

		req.on('error', (err)->console.log err)
		req.write params 
		req.end()


	set_chatroom: (chatroom)->
		params = JSON.stringify({
			'chatroom': chatroom
		})
		headers = {
			'Content-Type': 'application/json',
			'Content-Length':  Buffer.byteLength(params, 'utf-8')
		}
		options = {
			host: @url,
			port: @port,
			path: '/episodes/' + @id_emission + '/chatroom',
			method: 'patch',
			form: params,
			headers: headers
		}
		req = http.request options, (res)-> 
		req.on('error',(err)->console.log err)
		req.write params 
		req.end()


module.exports = Backend