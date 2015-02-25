Db = require 'db'
Dom = require 'dom'
Modal = require 'modal'
Icon = require 'icon'
Loglist = require 'loglist'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Form = require 'form'
Time = require 'time'
Colors = Plugin.colors()
Photo = require 'photo'
Social = require 'social'
{tr} = require 'i18n'

exports.render = !->
	if Page.state.get(0)
		renderHunt Page.state.get(0), Page.state.get(1)
			# when a second id is passed along that photo is rendered without other stuff around it
		return

	rankings = Obs.create()
	Db.shared.ref('tahunts').observeEach (hunt) !->
		if hunt.get('winner')
			userWon = hunt.get('photos', hunt.get('winner'), 'userId')
			rankings.incr userWon, 10
			Obs.onClean !->
				rankings.incr userWon, -10

		hunt.observeEach 'photos', (photo) !->
			return if photo.get('userId') is userWon or !+photo.key()
			rankings.incr photo.get('userId'), 2
			Obs.onClean !->
				rankings.incr photo.get('userId'), -2

	Obs.observe !->
		log 'rankings', rankings.get()

	Dom.h1 !->
		Dom.style textAlign: 'center'
		Dom.text tr "Beste TA'ers"

	meInTop3 = false
	Dom.div !->
		Dom.style Box: true, padding: '4px 12px'
		sorted = (+k for k, v of rankings.get()).sort (a, b) -> rankings.get(b) - rankings.get(a)
		if !rankings.get(sorted[0])
			Dom.div !->
				Dom.style Flex: 1, textAlign: 'center', padding: '10px'
				Dom.text tr("Nog geen foto's gemaakt")
		else
			for i in [0..Math.min(2, sorted.length-1)] then do (i) !->
				Dom.div !->
					Dom.style Box: 'center vertical', Flex: 1
					Ui.avatar Plugin.userAvatar(sorted[i]), null, 80
					Dom.div !->
						Dom.style margin: '4px', textAlign: 'center'
						meInTop3 = true if Plugin.userId() is sorted[i]
						Dom.text Plugin.userName(sorted[i])
						Dom.div !->
							Dom.style fontSize: '75%'
							Dom.text tr("%1 points", rankings.get(sorted[i]))

	if !meInTop3
		Dom.div !->
			Dom.style fontSize: '75%', fontStyle: 'italic', paddingBottom: '8px', textAlign: 'center'
			Dom.text tr("(Je hebt %1 punt|en)", rankings.get(Plugin.userId())||0)

	Ui.list !->
		# next hunt
		Ui.item !->
			Dom.div !->
				Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
				Icon.render data: 'clock2', color: '#aaa', style: { display: 'block' }, size: 34
			Dom.div !->
				Dom.div tr("Een nieuwe hunt begint over")
				Dom.div !->
					Dom.style fontSize: '120%', fontWeight: 'bold'
					Time.deltaText Db.shared.get('next')

			Dom.onTap !->
				requestNewHunt = !->
					Server.call 'newHunt', 1, (done) !->
						if (done)
							require('modal').show tr("No more hunts"), tr("All hunts have taken place, contact the Happening makers about adding Nieuwe Hunts!")
				if Plugin.userId() is Plugin.ownerId()
					require('modal').show tr("Nieuwe Hunt"), tr("Every day a Nieuwe Hunt wil start somewhere between 10am and 10pm. You however (and admins), can trigger a Nieuwe Hunt manually (you added the TA Foto Hunt)."), (option) !->
						if option is 'new'
							requestNewHunt()
					, ['cancel', tr("Cancel"), 'new', tr("Nieuwe Hunt")]
				else if Plugin.userIsAdmin()
					require('modal').show tr("Nieuwe Hunt"), tr("Every day a Nieuwe Hunt wil start somewhere between 10am and 10pm. Admins however (and %1, who added the TA Foto Hunt), can trigger a Nieuwe Hunt manually.", Plugin.userName(Plugin.ownerId())), (option) !->
						if option is 'new'
							requestNewHunt()
					, ['cancel', tr("Cancel"), 'new', tr("Nieuwe Hunt")]
				else
					require('modal').show tr("Nieuwe Hunt"), tr("Every day a Nieuwe Hunt wil start somewhere between 10am and 10pm, unless an admin or %1 (who added the TA Foto Hunt) trigger a Nieuwe Hunt manually.", Plugin.userName(Plugin.ownerId()))


		Db.shared.observeEach 'tahunts', (hunt) !->
			Ui.item !->
				log 'hunt', hunt.get()
				winningPhoto = hunt.ref('photos', hunt.get('winner'))
				if key = winningPhoto.get('key')
					Dom.div !->
						Dom.style
							width: '70px'
							height: '70px'
							marginRight: '10px'
							background: "url(#{Photo.url key, 200}) 50% 50% no-repeat"
							backgroundSize: 'cover'
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						Dom.text hunt.get('subject')
						if hunt.get('winner')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text tr("%1 won!", Plugin.userName(hunt.get('photos', hunt.get('winner'), 'userId')))
								if (cnt = hunt.count('photos').get()-2)
									Dom.text ' (' + tr("%1 |runner-up|runners-up", cnt) + ')'

					if unread = Social.newComments(hunt.key())
						Dom.div !->
							Ui.unread unread, null, {marginLeft: '4px'}
				else
					showAsNewest = +hunt.key() is +Db.shared.get('tahunts', 'maxId') and Plugin.created() isnt hunt.get('time')
					Dom.div !->
						Dom.style width: '70px', height: '70px', marginRight: '10px', Box: 'center middle'
						Icon.render
							data: (if showAsNewest then 'new' else 'warn')
							style: { display: 'block' }
							size: 34
							color: (if showAsNewest then null else '#aaa')
					Dom.div !->
						Dom.style Flex: 1, fontSize: '120%'
						if showAsNewest
							Dom.text tr "Maak een foto..."
							Dom.div !->
								Dom.style fontSize: '120%', fontWeight: 'bold', color: Colors.highlight
								Dom.text hunt.get('subject')
						else
							Dom.text hunt.get('subject')
							Dom.div !->
								Dom.style fontSize: '75%', marginTop: '6px'
								Dom.text tr("De eerste krijgt %1 punten", 10)
								if (cnt = hunt.count('photos').get()-1) > 0
									Dom.text ' (' + tr("%1 disqualified |runner-up|runners-up", cnt) + ')'

					if unread = Social.newComments(hunt.key())
						Dom.div !->
							Ui.unread unread, null, {marginLeft: '4px'}

				Dom.onTap !->
					Page.nav [hunt.key()]

		, (hunt) -> # skip the maxId key
			if +hunt.key()
				-hunt.key()


renderHunt = (huntId, photoId) !->
	Dom.style padding: 0
	Page.setTitle Db.shared.get('tahunts', huntId, 'subject')

	winnerId = Db.shared.get 'tahunts', huntId, 'winner'
	photos = Db.shared.ref 'tahunts', huntId, 'photos'
	if photoId
		mainPhoto = photos.ref photoId
	else
		mainPhoto = photos.ref winnerId

	# remove button
	if mainPhoto.get('userId') is Plugin.userId() or Plugin.userIsAdmin()
		showDisqualify = Plugin.userIsAdmin() and mainPhoto.key() is winnerId
		Page.setActions
			icon: if showDisqualify then Plugin.resourceUri('icon-report-48.png') else Plugin.resourceUri('icon-trash-48.png')
			action: !->
				if showDisqualify
					question = tr "Remove, or disqualify photo?"
					options = ['cancel', tr("Cancel"), 'remove', tr("Remove"), 'disqualify', tr("Disqualify")]
				else
					question = tr "Remove photo?"
					options = ['cancel', tr("Cancel"), 'ok', tr("OK")]

				require('modal').show null, question, (option) !->
					if option isnt 'cancel'
						Server.sync 'removePhoto', huntId, mainPhoto.key(), (option is 'disqualify'), !->
							Db.shared.remove 'tahunts', huntId, 'winner'
							if option is 'disqualify'
								photos.set mainPhoto.key(), 'disqualified', true
							else
								photos.remove(mainPhoto.key())
						if photoId # don't navigate back from winner page
							Page.back()
				, options

	boxSize = Obs.create()
	Obs.observe !->
		width = Dom.viewport.get('width')
		cnt = (0|(width / 100)) || 1
		boxSize.set(0|(width-((cnt+1)*4))/cnt)

	if !photoId
		allowUpload = Obs.create(true) # when the current use has no photos yet, allow upload
		Db.shared.observeEach 'tahunts', huntId, 'photos', (photo) !->
			return if +photo.get('userId') isnt Plugin.userId()
			allowUpload.set false
			Obs.onClean !->
				allowUpload.set true

	Dom.div !->
		Dom.style backgroundColor: '#fff', paddingBottom: '2px', borderBottom: '2px solid #ccc'
		# main photo
		contain = Obs.create false
		if mainPhoto and mainPhoto.key()
			(require 'photoview').render
				key: mainPhoto.get('key')
				content: !->
					Ui.avatar Plugin.userAvatar(mainPhoto.get('userId')), !->
						Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0

					Dom.div !->
						Dom.style
							position: 'absolute'
							textAlign: 'right'
							bottom: '10px'
							right: '50px'
							textShadow: '0 1px 0 #000'
							color: '#fff'
						if photoId
							Dom.text tr("Runner-up by %1", Plugin.userName(mainPhoto.get('userId')))
						else
							Dom.text tr("Won by %1", Plugin.userName(mainPhoto.get('userId')))
						Dom.div !->
							Dom.style fontSize: '75%'
							Dom.text tr("%1 point|s", if photoId then 2 else 10)
		else if !photoId
			Dom.div !->
				Dom.style textAlign: 'center', padding: '16px'
				if allowUpload.get()
					addPhoto boxSize.get()-4, huntId
					Dom.div !->
						Dom.style textAlign: 'center', marginBottom: '16px'
						Dom.text tr 'The first one wins 10 points!'
				else
					Dom.text tr "You have already submitted a photo for this Hunt..."

		# we're only rendering other submissions and comments when it's the winner being displayed
		if !photoId
			photos = Db.shared.ref 'tahunts', huntId, 'photos'
			# do we have a winner, or runner-ups?
			if winnerId or photos.count().get()>(1 + if winnerId then 1 else 0)
				Dom.div !->
					Dom.style padding: '2px'

					Dom.h2 !->
						Dom.style margin: '8px 2px 4px 2px'
						Dom.text tr "Runners-up (2 points)"

					photos.observeEach (photo) !->
						return if +photo.key() is winnerId
						Dom.div !->
							Dom.cls 'photo'
							Dom.style
								display: 'inline-block'
								position: 'relative'
								margin: '2px'
								height: (boxSize.get()) + 'px'
								width: (boxSize.get()) + 'px'
								backgroundImage: Photo.css photo.get('key'), 200
								backgroundSize: 'cover'
								backgroundPosition: '50% 50%'
								backgroundRepeat: 'no-repeat'
							Ui.avatar Plugin.userAvatar(photo.get('userId')), !->
								Dom.style position: 'absolute', bottom: '4px', right: '4px', margin: 0
							Dom.onTap !->
								Page.nav [huntId, photo.key()]
					, (photo) ->
						if +photo.key()
							photo.key()

					if allowUpload.get() and winnerId
						addPhoto boxSize.get()-4, huntId
					else if photos.count().get()<=(1 + if winnerId then 1 else 0) # maxId is also counted
						Dom.div !->
							Dom.style padding: '2px', color: '#aaa'
							Dom.text tr "No runners-up submitted"

	if !photoId
		log 'comments >>> '+huntId
		Social.renderComments huntId, render: (comment) ->
			if comment.s and comment.u
				comment.c = Plugin.userName(comment.u) + ' ' + comment.c
				Dom.div !->
					Dom.style margin: '6px 0 6px 56px', fontSize: '70%'

					Dom.span !->
						Dom.style color: '#999'
						Time.deltaText comment.t
						Dom.text " • "

					Dom.text comment.c
				true # We're rendering these type of comments

addPhoto = (size, huntId) !->
	Dom.div !->
		Dom.cls 'add'
		Dom.style
			display: 'inline-block'
			position: 'relative'
			verticalAlign: 'top'
			margin: '2px'
			background:  "url(#{Plugin.resourceUri('addphoto.png')}) 50% 50% no-repeat"
			backgroundSize: '32px'
			border: 'dashed 2px #aaa'
			height: size + 'px'
			width: size + 'px'
		Dom.onTap !->
			Photo.pick 'camera', [huntId]

Dom.css
	'.add.tap::after, .photo.tap::after':
		content: '""'
		display: 'block'
		position: 'absolute'
		left: 0
		right: 0
		top: 0
		bottom: 0
		backgroundColor: 'rgba(0, 0, 0, 0.2)'
