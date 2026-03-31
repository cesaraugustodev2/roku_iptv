sub Main(args)
    ' Deep linking support: standard Roku contentId and mediaType
    contentId = ""
    mediaType = ""
    if args.contentId <> invalid then contentId = args.contentId
    if args.mediaType <> invalid then mediaType = args.mediaType

    ' Legacy/Custom deep linking support: allow sending a playlist URL via args
    url = ""
    if args.url <> invalid and args.url <> ""
        url = args.url
    end if

    reg = CreateObject("roRegistrySection", "profile")
    
    if url <> ""
        ' If a URL was sent via deep link, we prioritize it and save it
        reg.Write("primaryfeed", url)
        reg.Flush()
        ' Also clear Xtream data to avoid confusion if we are switching to M3U
        reg.Delete("xtream_server")
        reg.Delete("xtream_user")
        reg.Delete("xtream_pass")
        reg.Flush()
    else
        if reg.Exists("primaryfeed")
            url = reg.Read("primaryfeed")
        else
            url = ""
        end if
    end if

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)
    m.global = screen.getGlobalNode()
    
    ' Add deep link fields to global
    m.global.addFields({
        feedurl: url,
        deeplink: {
            contentId: contentId,
            mediaType: mediaType
        }
    })
    
    scene = screen.CreateScene("MainScene")
    screen.show()
    scene.setFocus(true)

    while(true) 
        msg = wait(0, m.port)
        msgType = type(msg)
        if msgType = "roSGScreenEvent"
            if msg.isScreenClosed() then return
        elseif msgType = "roAppManagerEvent"
            ' Handle deep link while app is already running
            if msg.isRequestSucceeded()
                params = msg.GetData()
                if (params.url <> invalid and params.url <> "") or (params.contentId <> invalid and params.contentId <> "")
                    deepLink = {
                        contentId: "",
                        mediaType: ""
                    }
                    if params.contentId <> invalid then deepLink.contentId = params.contentId
                    if params.mediaType <> invalid then deepLink.mediaType = params.mediaType
                    
                    if params.url <> invalid and params.url <> ""
                        m.global.feedurl = params.url
                    end if
                    
                    m.global.deeplink = deepLink
                end if
            end if
        end if
    end while
    
end sub