sub init()
    m.top.functionName = "getContent"
end sub

sub getContent()
    server = m.top.server
    username = m.top.username
    password = m.top.password
    action = m.top.action

    if server = "" or username = "" or password = "" return

    if not (Left(server, 7) = "http://" or Left(server, 8) = "https://")
        server = "http://" + server
    end if

    transfer = CreateObject("roUrlTransfer")
    uEnc = transfer.Escape(username)
    pEnc = transfer.Escape(password)
    baseUrl = server + "/player_api.php?username=" + uEnc + "&password=" + pEnc
    
    if action = "all"
        fetchCategoriesOnly(baseUrl, server, uEnc, pEnc)
    elseif action = "epg"
        fetchEPG(baseUrl)
    elseif action = "series_info"
        fetchSeriesInfo(baseUrl, server, uEnc, pEnc)
    elseif action = "category_streams"
        fetchCategoryStreams(baseUrl, server, uEnc, pEnc)
    elseif action = "search"
        fetchSearch(baseUrl, server, uEnc, pEnc)
    end if
end sub

sub fetchSearch(baseUrl as String, server as String, user as String, pass as String)
    query = LCase(m.top.search_query)
    if query = "" return

    rootNode = CreateObject("roSGNode", "ContentNode")
    
    ' Standard Xtream API doesn't have a global search endpoint across all types
    ' So we fetch VOD and Series (Live is usually less searched this way)
    ' We search within categories if needed, but here we'll try to get all VOD/Series
    ' and filter them if the list isn't astronomically large, or just fetch categories first.
    
    ' However, for modern Xtream, we often fetch categories and then search names.
    ' To be efficient, we'll fetch the category lists and see if the query matches category names
    ' AND also try to fetch some streams if possible.
    
    ' Better approach: Fetch VOD streams for 'all' category (0) if the server allows it
    ' then filter on client side.
    
    types = ["vod", "series"]
    for each t in types
        action = "get_vod_streams"
        if t = "series" then action = "get_series"
        
        url = baseUrl + "&action=" + action
        print "--- fetchSearch: Fetching "; t; " from "; url
        items = makeRequest(url)
        
        if items <> invalid and type(items) = "roArray"
            count = 0
            for each item in items
                title = ""
                if item.name <> invalid then title = item.name
                if item.title <> invalid then title = item.title
                
                if title <> "" and Instr(1, LCase(title), query) > 0
                    node = rootNode.CreateChild("ContentNode")
                    node.title = title
                    
                    streamId = ""
                    if item.stream_id <> invalid then streamId = item.stream_id.ToStr()
                    if item.series_id <> invalid then streamId = item.series_id.ToStr()
                    node.id = streamId
                    
                    if t = "vod"
                        ext = "mp4"
                        if item.container_extension <> invalid and item.container_extension <> "" then ext = item.container_extension
                        node.url = server + "/movie/" + user + "/" + pass + "/" + streamId + "." + ext
                        node.contentType = "VOD"
                        node.streamFormat = ext
                    else
                        node.contentType = "SERIES"
                    end if
                    
                    count = count + 1
                    if count > 100 exit for ' Limit search results to avoid memory issues
                end if
            end for
            print "--- fetchSearch: Found "; count; " matches in "; t
        end if
    end for
    
    m.top.search_results = rootNode
end sub

sub fetchCategoriesOnly(baseUrl as String, _server as String, _user as String, _pass as String)
    rootNode = CreateObject("roSGNode", "ContentNode")

    ' --- 1. Fetch Live TV Categories ---
    liveUrl = baseUrl + "&action=get_live_categories"
    print "--- fetchCategoriesOnly: Fetching live from "; liveUrl
    liveCategories = getCachedOrFetch(liveUrl)
    if liveCategories <> invalid
        processCategories(rootNode, liveCategories, "Live TV", "live")
    else
        print "!!! fetchCategoriesOnly: Live categories fetch failed"
    end if

    ' --- 2. Fetch Movies (VOD) Categories ---
    vodUrl = baseUrl + "&action=get_vod_categories"
    vodCategories = getCachedOrFetch(vodUrl)
    if vodCategories <> invalid
        processCategories(rootNode, vodCategories, "Movies", "movie")
    end if

    ' --- 3. Fetch Series Categories ---
    seriesUrl = baseUrl + "&action=get_series_categories"
    seriesCategories = getCachedOrFetch(seriesUrl)
    if seriesCategories <> invalid
        processCategories(rootNode, seriesCategories, "Series", "series")
    end if

    print "--- fetchCategoriesOnly: Total combined count: "; rootNode.getChildCount()
    m.top.content = rootNode
end sub

function getCachedOrFetch(url as String) as Object
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(url)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    hash = digest.Process(ba)
    filename = "tmp:/" + hash + ".json"
    
    fs = CreateObject("roFileSystem")
    
    ' Check if cache exists and is recent (within 6 hours)
    if fs.Exists(filename)
        stat = fs.Stat(filename)
        if stat <> invalid and stat.mtime <> invalid
            now = CreateObject("roDateTime")
            cacheAge = now.AsSeconds() - stat.mtime
            ' Cache valid for 6 hours (21600 seconds)
            if cacheAge < 21600
                content = ReadAsciiFile(filename)
                if content <> ""
                    json = ParseJson(content)
                    if json <> invalid
                        print "--- getCachedOrFetch: Using cache (age: "; Int(cacheAge / 60); " min)"
                        return json
                    end if
                end if
            end if
        end if
    end if
    
    ' Fetch fresh data
    json = makeRequest(url)
    if json <> invalid
        ' Save to cache (overwrite if exists)
        WriteAsciiFile(filename, FormatJson(json))
    end if
    
    return json
end function

sub processCategories(rootNode as Object, categories as Object, _titlePrefix as String, streamType as String)
    if categories = invalid return
    
    ' Xtream API can return Array or Object depending on version
    if type(categories) = "roArray"
        for each cat in categories
            if cat.category_id <> invalid
                node = rootNode.CreateChild("ContentNode")
                node.id = streamType + "_" + cat.category_id.ToStr()
                node.title = cat.category_name
                node.description = streamType
            end if
        end for
    elseif type(categories) = "roAssociativeArray"
        for each key in categories
            cat = categories[key]
            if cat <> invalid and cat.category_id <> invalid
                node = rootNode.CreateChild("ContentNode")
                node.id = streamType + "_" + cat.category_id.ToStr()
                node.title = cat.category_name
                node.description = streamType
            end if
        end for
    end if
    print "--- processCategories ["; streamType; "]: Added children. Current total children in rootNode: "; rootNode.getChildCount()
end sub

sub fetchCategoryStreams(baseUrl as String, server as String, user as String, pass as String)
    catId = m.top.category_id
    streamType = m.top.stream_type
    
    action = ""
    if streamType = "live"
        action = "get_live_streams"
    elseif streamType = "movie"
        action = "get_vod_streams"
    elseif streamType = "series"
        action = "get_series"
    end if
    
    if action = "" return

    url = baseUrl + "&action=" + action + "&category_id=" + catId
    print "--- fetchCategoryStreams: URL: "; url
    streams = makeRequest(url)
    
    rootNode = CreateObject("roSGNode", "ContentNode")
    if streams <> invalid and type(streams) = "roArray"
        streamCount = streams.Count()
        print "--- fetchCategoryStreams: Processing "; streamCount; " streams"
        
        for each stream in streams
            item = rootNode.CreateChild("ContentNode")
            
            ' Title
            if stream.name <> invalid
                item.title = stream.name
            elseif stream.title <> invalid
                item.title = stream.title
            end if
            
            ' Stream ID
            streamId = ""
            if stream.stream_id <> invalid
                streamId = stream.stream_id.ToStr()
            elseif stream.series_id <> invalid
                streamId = stream.series_id.ToStr()
            end if
            item.id = streamId
            
            ' Build URL based on type
            if streamType = "live"
                item.url = server + "/live/" + user + "/" + pass + "/" + streamId + ".ts"
                item.streamFormat = "ts"
                item.contentType = "LIVE"
            elseif streamType = "movie"
                ext = "mp4"
                if stream.container_extension <> invalid and stream.container_extension <> ""
                    ext = stream.container_extension
                end if
                item.url = server + "/movie/" + user + "/" + pass + "/" + streamId + "." + ext
                item.streamFormat = ext
                item.contentType = "VOD"
            elseif streamType = "series"
                item.url = "" 
                item.id = streamId
                item.contentType = "SERIES"
            end if
        end for
    end if
    
    m.top.category_content = rootNode
end sub

sub fetchEPG(baseUrl as String)
    streamId = m.top.stream_id
    if streamId = "" return
    
    response = makeRequest(baseUrl + "&action=get_short_epg&stream_id=" + streamId)
    if response <> invalid and response.epg_listings <> invalid
        epgNode = CreateObject("roSGNode", "ContentNode")
        for each entry in response.epg_listings
            item = epgNode.CreateChild("ContentNode")
            item.title = entry.title
            item.description = entry.description
            item.releaseDate = entry.start
            item.id = entry.id
        end for
        m.top.epg_data = epgNode
    end if
end sub

sub fetchSeriesInfo(baseUrl as String, server as String, user as String, pass as String)
    seriesId = m.top.stream_id
    if seriesId = "" return
    
    print "--- fetchSeriesInfo: series_id="; seriesId
    response = makeRequest(baseUrl + "&action=get_series_info&series_id=" + seriesId)
    
    if response <> invalid and response.episodes <> invalid
        print "--- fetchSeriesInfo: Got response with episodes"
        seriesInfo = CreateObject("roSGNode", "ContentNode")
        
        episodes = response.episodes
        if type(episodes) = "roAssociativeArray"
            for each seasonKey in episodes
                seasonNode = seriesInfo.CreateChild("ContentNode")
                seasonNode.title = "Season " + seasonKey
                seasonNode.contentType = "SECTION"
                seasonEpisodes = episodes[seasonKey]
                if type(seasonEpisodes) = "roArray"
                    print "--- fetchSeriesInfo: Season "; seasonKey; " has "; seasonEpisodes.Count(); " episodes"
                    for each episode in seasonEpisodes
                        item = seasonNode.CreateChild("ContentNode")
                        item.title = episode.title
                        print "    - Episode: "; item.title
                        ext = "mp4"
                        if episode.container_extension <> invalid and episode.container_extension <> ""
                            ext = episode.container_extension
                        end if
                        ' Fallback for ID
                        epId = ""
                        if episode.id <> invalid
                            epId = episode.id.ToStr()
                        elseif episode.episode_id <> invalid
                            epId = episode.episode_id.ToStr()
                        end if
                        item.url = server + "/series/" + user + "/" + pass + "/" + epId + "." + ext
                        item.id = epId
                        item.contentType = "VOD"
                        item.streamFormat = ext
                        if episode.info <> invalid and episode.info.plot <> invalid
                            item.description = episode.info.plot
                        end if
                    end for
                end if
            end for
        elseif type(episodes) = "roArray"
            ' Some servers return an array of seasons
            for i = 0 to episodes.Count() - 1
                season = episodes[i]
                seasonNode = seriesInfo.CreateChild("ContentNode")
                sNum = (i + 1).ToStr()
                if season.season_number <> invalid then sNum = season.season_number.ToStr()
                seasonNode.title = "Season " + sNum
                seasonNode.contentType = "SECTION"
                ' Handle episodes if nested or if this is the episodes list itself
                ' This part varies by server, but we attempt to find the array
            end for
        end if
        
        print "--- fetchSeriesInfo: Created "; seriesInfo.getChildCount(); " seasons"
        m.top.series_info = seriesInfo
    else
        print "!!! fetchSeriesInfo: Failed or no episodes found"
    end if
end sub

function makeRequest(url as String)
    transfer = CreateObject("roUrlTransfer")
    transfer.SetUrl(url)
    transfer.EnableEncodings(true)
    
    ' Bypass SSL issues
    transfer.EnablePeerVerification(false)
    transfer.EnableHostVerification(false)
    
    if url.Left(5) = "https"
        transfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
        transfer.InitClientCertificates()
    end if
    
    response = transfer.GetToString()
    if response <> ""
        print "--- makeRequest: Received "; response.Len(); " bytes"
        json = ParseJson(response)
        if json = invalid then print "!!! JSON Parse Fail for URL: "; url
        return json
    end if
    print "!!! Empty Response for URL: "; url
    return invalid
end function
