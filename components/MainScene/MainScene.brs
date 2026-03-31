sub init()
    ' Node references
    m.list = m.top.FindNode("list")
    m.video = m.top.FindNode("Video")
    m.videoFrame = m.top.FindNode("videoFrame")
    m.sidebarList = m.top.FindNode("sidebarList")
    
    m.dashboard = m.top.FindNode("dashboard")
    m.categoryView = m.top.FindNode("categoryView")
    m.contentView = m.top.FindNode("contentArea")
    m.mainContainer = m.top.FindNode("mainContainer")
    m.dTime = m.top.FindNode("dashboardTime")
    
    ' Tasks
    m.get_channel_list = m.top.FindNode("get_channel_list")
    m.xtream_task = m.top.FindNode("XtreamTask")

    m.get_channel_list.ObserveField("content", "onM3UGroupsLoaded")
    m.get_channel_list.ObserveField("group_content", "onM3UChannelsLoaded")
    m.get_channel_list.ObserveField("log_message", "onLoadingMessage")
    
    m.xtream_task.ObserveField("content", "onCategoriesLoaded")
    m.xtream_task.ObserveField("category_content", "onStreamsLoaded")
    m.xtream_task.ObserveField("series_info", "onSeriesInfoUpdate")
    m.xtream_task.ObserveField("search_results", "onSearchResultsLoaded")

    m.loadingIndicator = m.top.FindNode("loadingIndicator")

    ' Observers
    m.list.ObserveField("itemSelected", "onListItemSelected") 
    m.list.ObserveField("itemFocused", "onItemFocused")
    m.sidebarList.ObserveField("itemSelected", "onSidebarSelected")
    m.sidebarList.ObserveField("itemFocused", "onSidebarFocused")
    m.video.ObserveField("state", "checkState")
    m.video.ObserveField("bufferingStatus", "onBufferingStatusChange")
    m.video.enableCookies = true
    m.global.ObserveField("feedurl", "onGlobalFeedUrlChange")
    m.global.ObserveField("deeplink", "onDeepLinkChange")
    
    ' State
    m.navigationDepth = 0 ' 0: Categories, 1: Streams
    m.viewMode = "channels" ' channels, vod
    m.isFullScreen = false

    ' Initial Setup
    loadTranslations()
    setupSidebar()
    startClock()
    setupAutoReloadTimer()
    
    ' --- CONFIG VERSIONING SYSTEM ---
    ' Whenever you want to force all users (including yourself) to use a new playlist updated in the code, 
    ' simply increment THIS 'configVersion' number.
    m.configVersion = 3 ' Increment this to force update
    
    reg = CreateObject("roRegistrySection", "profile")
    savedVersion = 0
    if reg.Exists("config_version") then savedVersion = reg.Read("config_version").toInt()
    
    if savedVersion < m.configVersion
        print "--- init: New config version detected ("; m.configVersion; ") - applying latest defaults"
        
        ' NEW DEFAULTS HERE
        newServer = "server_URL"
        newUser = "server_user"
        newPass = "server_pass"
        
        reg.Write("xtream_server", newServer)
        reg.Write("xtream_user", newUser)
        reg.Write("xtream_pass", newPass)
        reg.Write("config_version", m.configVersion.toStr())
        
        ' Optionally clear any old M3U link to prioritize the new Xtream list
        if reg.Exists("primaryfeed") then reg.Delete("primaryfeed")
        
        reg.Flush()
    end if
    ' --------------------------------

    hasXtream = (reg.Exists("xtream_server") and reg.Read("xtream_server") <> "")
    hasM3U = (reg.Exists("primaryfeed") and reg.Read("primaryfeed") <> "")
    
    ' (Legacy/Fallback) If no playlist is configured at all
    if not hasXtream and not hasM3U
        print "--- init: No playlist found at all - configuring latest known defaults"
        reg.Write("xtream_server", "server_URL")
        reg.Write("xtream_user", "server_user")
        reg.Write("xtream_pass", "server_pass")
        reg.Write("config_version", m.configVersion.toStr())
        reg.Flush()
        hasXtream = true
    end if
    
    print "--- init: hasXtream="; hasXtream; " hasM3U="; hasM3U
    
    if hasXtream
        loadXtreamContent()
    elseif hasM3U
        loadM3UContent()
    end if

    ' Ensure sidebar starts at first item (Live TV)
    m.sidebarList.jumpToItem = 0
    m.sidebarList.itemFocused = 0
    m.sidebarList.SetFocus(true)
    
    ' Ensure the category view is visible
    m.dashboard.visible = false
    m.categoryView.visible = true

    ' Handle potential deep link from launch
    if m.global.deeplink <> invalid and m.global.deeplink.contentId <> ""
        handleDeepLink(m.global.deeplink)
    end if
end sub

sub onDeepLinkChange()
    if m.global.deeplink <> invalid and m.global.deeplink.contentId <> ""
        handleDeepLink(m.global.deeplink)
    end if
end sub

sub handleDeepLink(deeplink as Object)
    print "--- handleDeepLink: contentId="; deeplink.contentId; " mediaType="; deeplink.mediaType
    
    ' Construct a dummy content node for the deep link
    ' Note: In a real scenario, we might want to fetch full metadata first
    ' but for Xtream API, we can often trigger info fetch directly if we have the ID
    content = CreateObject("roSGNode", "ContentNode")
    content.id = deeplink.contentId
    
    if deeplink.mediaType = "series" or deeplink.mediaType = "tvseries" or deeplink.mediaType = "season"
        content.contentType = "SERIES"
        playChannel(content)
    elseif deeplink.mediaType = "movie" or deeplink.mediaType = "vod"
        content.contentType = "VOD"
    elseif deeplink.mediaType = "live"
        content.contentType = "LIVE"
    end if
end sub

sub onFocusReady()
    ' Obsolete - no longer needed since we auto-configure
end sub

sub showInitialDialog()
    ' Obsolete - no longer needed since we auto-configure
end sub

sub setupSidebar()
    sidebarData = CreateObject("roSGNode", "ContentNode")
    menuItems = [
        { title: "TV AO VIVO", id: "live", icon: "https://img.icons8.com/ios-filled/512/FFFFFF/television.png" },
        { title: "FILMES", id: "movie", icon: "https://img.icons8.com/ios-filled/512/FFFFFF/movie.png" },
        { title: "SÉRIES", id: "series", icon: "https://img.icons8.com/ios-filled/512/FFFFFF/tv-show.png" },
        { title: "FAVORITOS", id: "favorites", icon: "https://img.icons8.com/ios-filled/512/FFFFFF/star.png" },
        { title: "BUSCAR", id: "search", icon: "https://img.icons8.com/ios-filled/512/FFFFFF/search.png" }
    ]
    for each item in menuItems
        node = sidebarData.CreateChild("ContentNode")
        node.title = item.title
        node.id = item.id
        node.HDLISTITEMICONURL = item.icon
    end for
    m.sidebarList.content = sidebarData
end sub

sub onLoadingMessage(event as Object)
    msg = event.getData()
    if m.loadingText <> invalid then m.loadingText.text = msg
end sub

sub onSidebarFocused()
    if not m.sidebarList.hasFocus() return
    onSidebarSelected()
end sub

sub onSidebarSelected()
    idx = m.sidebarList.itemFocused
    if idx < 0 then idx = m.sidebarList.itemSelected
    if idx < 0 then return

    print "--- onSidebarSelected: idx "; idx
    
    if idx = 3 ' Favorites
        m.viewMode = "favorites"
        m.dashboard.visible = false
        m.categoryView.visible = true
        m.navigationDepth = 1
        showFavorites()
    elseif idx = 4 ' Search
        showSearchDialog()
    else
        m.viewMode = "channels"
        m.dashboard.visible = false
        m.categoryView.visible = true
        m.navigationDepth = 0
        filterContentBySidebar()
    end if
end sub

sub onSearchResultsLoaded(event as Object)
    data = event.getData()
    if data <> invalid
        print "--- onSearchResultsLoaded: Count "; data.getChildCount()
        m.viewMode = "search"
        m.navigationDepth = 1
        activeList = getActiveList()
        activeList.content = data
        activeList.jumpToItem = 0
        activeList.SetFocus(true)
    else
        print "!!! onSearchResultsLoaded: Received invalid data"
    end if
    m.loadingIndicator.visible = false
end sub

sub showSearchDialog()
    k = createObject("roSGNode", "KeyboardDialog")
    k.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    k.title = UCase(m.top.FindNode("sidebarList").content.getChild(4).title)
    k.buttons = [UCase(GetString("connect")), UCase(GetString("cancel"))]
    m.top.dialog = k
    m.top.dialog.observeFieldScoped("buttonSelected", "onSearchKeyPress")
end sub

sub onSearchKeyPress()
    if m.top.dialog.buttonSelected = 0
        query = m.top.dialog.text
        m.top.dialog.close = true
        if query <> ""
            m.loadingIndicator.visible = true
            m.xtream_task.search_query = query
            m.xtream_task.action = "search"
            m.xtream_task.control = "RUN"
        end if
    else
        m.top.dialog.close = true
    end if
end sub

sub onCategoriesLoaded(event as Object)
    data = event.getData()
    if data <> invalid
        print "--- onCategoriesLoaded: Recebidos "; data.getChildCount(); " grupos"
        m.allCategories = data
        m.navigationDepth = 0
        filterContentBySidebar()
    else
        print "!!! onCategoriesLoaded: Received invalid data"
    end if
    m.loadingIndicator.visible = false
end sub

sub onStreamsLoaded(event as Object)
    data = event.getData()
    if data <> invalid
        print "--- onStreamsLoaded: Count "; data.getChildCount()
        m.navigationDepth = 1
        activeList = getActiveList()
        activeList.content = data
        activeList.jumpToItem = 0
        activeList.SetFocus(true)
    else
        print "!!! onStreamsLoaded: Received invalid data"
    end if
    m.loadingIndicator.visible = false
end sub

function getActiveList() as Object
    return m.list
end function

sub onM3UGroupsLoaded(event as Object)
    data = event.getData()
    print "--- onM3UGroupsLoaded: Count "; data.getChildCount()
    m.allCategories = data
    if m.allCategories <> invalid
        m.navigationDepth = 0
        filterContentBySidebar()
    end if
    m.loadingIndicator.visible = false
end sub

sub onM3UChannelsLoaded(event as Object)
    data = event.getData()
    if data <> invalid and m.list <> invalid
        m.list.content = data
        m.navigationDepth = 1
        m.list.SetFocus(true)
    end if
    m.loadingIndicator.visible = false
end sub

sub filterContentBySidebar()
    if m.allCategories = invalid return
    
    idx = m.sidebarList.itemFocused
    if idx < 0 then idx = m.sidebarList.itemSelected
    
    prefix = ""
    if idx = 0 then prefix = "live_" : m.viewMode = "channels"
    if idx = 1 then prefix = "movie_" : m.viewMode = "vod"
    if idx = 2 then prefix = "series_" : m.viewMode = "vod"
    
    filtered = CreateObject("roSGNode", "ContentNode")
    for i = 0 to m.allCategories.getChildCount() - 1
        cat = m.allCategories.getChild(i)
        catId = ""
        if cat.id <> invalid then catId = cat.id
        
        ' Filter by prefix (Xtream) or include all M3U groups in the first tab
        if prefix <> "" and Left(catId, prefix.Len()) = prefix
            filtered.appendChild(cat.Clone(true))
        elseif idx = 0 and Left(catId, 4) = "m3u_"
            filtered.appendChild(cat.Clone(true))
        end if
    end for

    m.currentCategoryList = filtered
    print "--- filterContentBySidebar: filtered count "; filtered.getChildCount(); " for prefix "; prefix
    
    ' Always use LabelList
    m.list.visible = true
    m.list.content = filtered
    
    if filtered.getChildCount() = 0 and m.allCategories <> invalid
        print "!!! filterContentBySidebar: No categories matched prefix. All categories total: "; m.allCategories.getChildCount()
    end if
    
    m.navigationDepth = 0
end sub

sub showFavorites()
    favs = getFavorites()
    content = CreateObject("roSGNode", "ContentNode")
    for each f in favs
        node = content.CreateChild("ContentNode")
        node.Update(f, true)
    end for
    
    activeList = getActiveList()
    activeList.content = content
    m.list.visible = true
    if not m.sidebarList.hasFocus() then activeList.SetFocus(true)
end sub

function getFavorites() as Object
    reg = CreateObject("roRegistrySection", "profile")
    if reg.Exists("favorites")
        favs = ParseJson(reg.Read("favorites"))
        if favs <> invalid return favs
    end if
    return []
end function

sub toggleFavorite(item as Object)
    if item = invalid return
    favs = getFavorites()
    id = item.id
    foundIdx = -1
    for i = 0 to favs.Count() - 1
        if favs[i].id = id
            foundIdx = i
            exit for
        end if
    end for
    
    if foundIdx >= 0
        favs.Delete(foundIdx)
    else
        ' Store only necessary fields to save space
        favItem = {
            id: item.id,
            title: item.title,
            url: item.url,
            streamFormat: item.streamFormat,
            contentType: item.contentType,
            HDLISTITEMICONURL: item.HDLISTITEMICONURL,
            hdPosterUrl: item.hdPosterUrl,
            description: item.description
        }
        favs.Push(favItem)
    end if
    
    reg = CreateObject("roRegistrySection", "profile")
    reg.Write("favorites", FormatJson(favs))
    reg.Flush()
    
    if m.viewMode = "favorites" then showFavorites()
end sub

sub startClock()
    m.timer = CreateObject("roSGNode", "Timer")
    m.timer.duration = 60
    m.timer.repeat = true
    m.timer.ObserveField("fire", "updateTime")
    m.timer.control = "start"
    updateTime()
end sub

sub updateTime()
    date = CreateObject("roDateTime")
    date.toLocalTime()
    h = date.getHours()
    m_val = date.getMinutes() + 100
    m_str = m_val.toStr().right(2)
    timeStr = h.toStr() + ":" + m_str
    
    if m.currentTime <> invalid then m.currentTime.text = timeStr
    if m.dTime <> invalid then m.dTime.text = timeStr
    
    ' Update Date
    months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    dateStr = months[date.getMonth()-1] + " " + date.getDayOfMonth().toStr() + ", " + date.getYear().toStr()
    if m.dDate <> invalid then m.dDate.text = dateStr
end sub

sub onItemFocused()
end sub



function getFocusedContent()
    target = getActiveList()
    if m.sidebarList.hasFocus() then target = m.sidebarList
    
    if target.content = invalid return invalid
    f = target.itemFocused
    if f < 0 then f = 0
    return target.content.getChild(f)
end function

sub onListItemSelected()
    ' Determine which list to pull from based on focus
    focused = m.top.focusedChild
    focusedId = ""
    if focused <> invalid then focusedId = focused.id
    
    if m.sidebarList.hasFocus() or focusedId = "sidebarList"
        onSidebarSelected()
        return
    end if

    content = getFocusedContent()
    if content = invalid
        print "!!! onListItemSelected: Content is invalid"
        return
    end if
    
    id = ""
    if content.id <> invalid then id = content.id
    print "--- onListItemSelected: depth "; m.navigationDepth; " id "; id
    
    if m.navigationDepth = 0
        m.loadingIndicator.visible = true
        if Left(id, 4) = "m3u_"
             m.get_channel_list.group_id = Mid(id, 5)
             m.get_channel_list.action = "get_group"
             m.get_channel_list.control = "RUN"
             print "--- onListItemSelected: Triggered M3U task for group "; Mid(id, 5)
        elseif id <> "" and Instr(1, id, "_") > 0
            p = id.Split("_")
            if p.Count() >= 2
                m.xtream_task.category_id = p[1]
                m.xtream_task.stream_type = p[0]
                m.xtream_task.action = "category_streams"
                m.xtream_task.control = "RUN"
                print "--- onListItemSelected: Triggered Xtream task for "; p[0]; " / "; p[1]
            end if
        else
            print "--- onListItemSelected: Playing direct stream"
            m.loadingIndicator.visible = false
            playChannel(content)
        end if
    else
        print "--- onListItemSelected: Selecting item at depth "; m.navigationDepth
        cType = ""
        if content.contentType <> invalid then cType = content.contentType.toStr()
        print "--- onListItemSelected: Item title: "; content.title; " cType: "; cType
        
        if cType = "SECTION" or cType = "3" or cType = "16"
            ' It's a Season, show Episodes
            print "--- onListItemSelected: Entering season - moving to depth 2"
            m.currentSeasonList = m.list.content ' Store seasons to go back
            m.list.content = content
            m.navigationDepth = 2
            m.list.jumpToItem = 0
            return
        end if

        if m.navigationDepth = 2
            print "--- onListItemSelected: Playing episode"
        end if

        if m.video.content <> invalid and m.video.content.url = content.url
            setFullScreen(true)
        else
            playChannel(content)
        end if
    end if
end sub

sub playChannel(content as Object)
    ' Safely get contentType as a string to avoid Type Mismatch
    cType = ""
    if content.contentType <> invalid then cType = content.contentType.toStr()

    if cType = "SERIES" or cType = "2"
        print "--- playChannel: Detected SERIES, fetching info for stream_id "; content.id
        m.xtream_task.action = "series_info"
        m.xtream_task.stream_id = content.id
        m.xtream_task.control = "RUN"
        m.loadingIndicator.visible = true
        return
    end if
    
    if content.url = "" or content.url = invalid return
    
    m.loadingIndicator.visible = false
    
    videoContent = CreateObject("roSGNode", "ContentNode")
    videoContent.url = content.url
    videoContent.title = content.title
    videoContent.streamFormat = content.streamFormat
    
    ' Common fix for stream freezes: Set a stable browser User-Agent
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36",
        "Connection": "keep-alive"
    }
    
    ' ContentNode doesn't have HttpHeader by default, we must add it
    videoContent.addFields({
        HttpHeader: headers,
        minBandwidth: 1000 ' 1Mbps as a stable floor for HD streams
    })
    
    if cType = "LIVE" or content.Live = true
        videoContent.Live = true
    end if
    
    ' Position for side preview window
    ' Sidebar is 300px, content area is 1620px wide
    ' Place video on right side: 300 (sidebar) + 570 (list area) = 870
    m.video.width = 1000
    m.video.height = 562
    m.video.translation = [870, 250]  ' Adjusted Y position to align with content
    m.video.visible = true
    
    m.video.content = videoContent
    print "--- playChannel: Playing URL: "; videoContent.url
    m.video.control = "play"
    
    updateLayout(true)
    
    m.list.SetFocus(false)
    m.video.SetFocus(true)
end sub

sub updateLayout(videoActive as Boolean)
    if videoActive
        m.list.itemSize = [800, 90]
        m.video.width = 1000
        m.video.height = 562
        m.video.translation = [870, 250]
        m.video.visible = true
        if m.videoFrame <> invalid
            m.videoFrame.visible = true
        end if
    else
        m.list.itemSize = [1500, 90]
        m.video.visible = false
        m.video.control = "stop"
        if m.videoFrame <> invalid
            m.videoFrame.visible = false
        end if
    end if
end sub

sub setFullScreen(enable as Boolean)
    m.isFullScreen = enable
    if enable
        m.categoryView.visible = false
        m.video.translation = [0, 0]
        m.video.width = 1920
        m.video.height = 1080
        if m.videoFrame <> invalid then m.videoFrame.visible = false
    else
        m.categoryView.visible = true
        updateLayout(true)
        m.list.SetFocus(true)
    end if
end sub

sub onSeriesInfoUpdate(event as Object)
    data = event.getData()
    if data <> invalid
        print "--- onSeriesInfoUpdate: Received "; data.getChildCount(); " seasons"
        m.list.content = data
        m.list.SetFocus(true)
        m.list.jumpToItem = 0
    else
        print "!!! onSeriesInfoUpdate: Received invalid data"
    end if
    m.loadingIndicator.visible = false
end sub

sub onGlobalFeedUrlChange()
    url = m.global.feedurl
    print "--- onGlobalFeedUrlChange: "; url
    if url <> "" and url <> invalid
        loadM3UContent()
    end if
end sub

sub loadM3UContent()
    reg = CreateObject("roRegistrySection", "profile")
    url = reg.Read("primaryfeed")
    print "--- loadM3UContent: URL from registry: "; url
    if url <> ""
        m.get_channel_list.url = url
        m.get_channel_list.action = "get_all"
        m.get_channel_list.control = "RUN"
        m.loadingIndicator.visible = true
        print "--- loadM3UContent: Task triggered for "; url
    else
        print "!!! loadM3UContent: No URL found in registry"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press return false
    key = LCase(key)
    
    ' Focus debug
    focused = m.top.focusedChild
    focusedId = "none"
    if focused <> invalid then focusedId = focused.id
    print "--- onKeyEvent: "; key; " (Focused: "; focusedId; " View: "; m.viewMode; " FullScreen: "; m.isFullScreen; ")"

    if m.isFullScreen
        if key = "back" or key = "ok"
            setFullScreen(false)
            return true
        end if
        return false
    end if

    if key = "back"
        if m.video.visible
             updateLayout(false)
             getActiveList().SetFocus(true)
             return true
        elseif getActiveList().hasFocus()
            if m.navigationDepth = 2
                m.navigationDepth = 1
                m.list.content = m.currentSeasonList
                return true
            elseif m.navigationDepth = 1 and m.viewMode <> "favorites"
                m.navigationDepth = 0
                getActiveList().content = m.currentCategoryList
                return true
            else
                m.sidebarList.SetFocus(true)
                return true
            end if
        end if
    elseif key = "right" and m.sidebarList.hasFocus()
        getActiveList().SetFocus(true)
        return true
    elseif key = "left" and not m.sidebarList.hasFocus()
        m.sidebarList.SetFocus(true)
        return true
    end if

    if m.sidebarList.hasFocus()
        return false ' Sidebar handles up/down normally
    end if

    if key = "ok"
        onListItemSelected()
        return true
    elseif key = "options"
        content = getFocusedContent()
        if content <> invalid
            toggleFavorite(content)
            return true
        end if
    elseif key.Len() = 1 and key >= "1" and key <= "9"
        playFavoriteByIndex(key.ToInt() - 1)
        return true
    end if
    
    return false
end function

sub playFavoriteByIndex(index as Integer)
    favs = getFavorites()
    if index < favs.Count()
        fav = favs[index]
        ' Create a Node to mimic the content node expected by playChannel
        content = CreateObject("roSGNode", "ContentNode")
        content.Update(fav, true)
        playChannel(content)
    end if
end sub

sub checkState()
    if m.video.state <> invalid then print "--- Video State: "; m.video.state
    if m.video.state = "error"
        print "!!! Video Error: "; m.video.errorCode; " - "; m.video.errorMsg
        
        ' Auto-reload on error (max 3 times)
        if m.playbackRetryCount < 3
            m.playbackRetryCount = m.playbackRetryCount + 1
            print "--- Auto-Reload: Error detected, retrying ("; m.playbackRetryCount; "/3)"
            reloadCurrentChannel()
        else
            d = CreateObject("roSGNode", "Dialog")
            d.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
            d.title = GetString("playback_error")
            d.message = m.video.errorMsg
            m.top.dialog = d
        end if
    elseif m.video.state = "buffering"
        m.loadingIndicator.visible = true
        ' If we stay in buffering for more than 10s, try a reload
        m.reloadTimer.control = "start"
    elseif m.video.state = "playing"
        m.loadingIndicator.visible = false
        m.reloadTimer.control = "stop"
        m.playbackRetryCount = 0 ' Reset on successful playback
    elseif m.video.state = "finished" or m.video.state = "stopped"
        m.reloadTimer.control = "stop"
    end if
end sub

sub setupAutoReloadTimer()
    m.reloadTimer = CreateObject("roSGNode", "Timer")
    m.reloadTimer.duration = 5 ' 5 seconds of buffering before reload - more aggressive
    m.reloadTimer.repeat = false
    m.reloadTimer.ObserveField("fire", "onReloadTimerFire")
    m.playbackRetryCount = 0
end sub

sub onReloadTimerFire()
    if m.video.state = "buffering"
        if m.playbackRetryCount < 3
            m.playbackRetryCount = m.playbackRetryCount + 1
            print "--- Auto-Reload: Buffering timeout, retrying ("; m.playbackRetryCount; "/3)"
            reloadCurrentChannel()
        else
            print "!!! Auto-Reload: Max retries reached"
            m.reloadTimer.control = "stop"
        end if
    end if
end sub

sub reloadCurrentChannel()
    if m.video.content <> invalid
        print "--- reloadCurrentChannel: Restarting stream..."
        ' Refresh the content node to trigger a fresh connection
        oldContent = m.video.content
        newContent = CreateObject("roSGNode", "ContentNode")
        newContent.Update(oldContent, true)
        
        ' Ensure the URL is re-evaluated and any session state is cleared
        m.video.control = "stop"
        m.video.content = newContent
        m.video.control = "play"
    end if
end sub

sub onBufferingStatusChange(event as Object)
    status = event.getData()
    if status <> invalid
        print "--- Buffering: "; status.percentage; "%"
        if status.percentage < 100
            m.loadingIndicator.visible = true
        else
            ' If we got to 100%, we should be playing soon, but state will handle hiding indicator
        end if
    end if
end sub

sub showdialog()
    d = createObject("roSGNode", "Dialog")
    d.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    d.title = UCase(GetString("select_format"))
    d.buttons = [UCase(GetString("m3u_url")), UCase(GetString("xtream_api")), UCase(GetString("manage_playlists"))]
    m.top.dialog = d
    m.top.dialog.observeFieldScoped("buttonSelected", "onFormatSelected")
end sub

sub onFormatSelected()
    b = m.top.dialog.buttonSelected
    m.top.dialog.close = true
    if b = 0 then showM3UDialog()
    if b = 1 then displayXtreamDialog("server")
    if b = 2 then showPlaylistManager()
end sub

sub showPlaylistManager()
    pList = getSavedPlaylists()
    if pList.Count() = 0 then showdialog() : return
    d = createObject("roSGNode", "Dialog")
    d.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    d.title = UCase(GetString("manage_playlists"))
    reg = CreateObject("roRegistrySection", "profile")
    act = reg.Read("active_playlist_index")
    labels = []
    for i = 0 to pList.Count() - 1
        n = pList[i].name
        if act <> "" and act.toInt() = i then n = n + " [ALIVE]"
        labels.Push(UCase(n))
    end for
    labels.Push(UCase(GetString("add_playlist")))
    labels.Push(UCase(GetString("cancel")))
    d.buttons = labels
    m.top.dialog = d
    m.top.dialog.observeFieldScoped("buttonSelected", "onPlaylistSelected")
end sub

sub onPlaylistSelected()
    m.selectedPlaylistIndex = m.top.dialog.buttonSelected
    pList = getSavedPlaylists()
    if m.selectedPlaylistIndex < pList.Count()
        d = createObject("roSGNode", "Dialog")
        d.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
        d.title = pList[m.selectedPlaylistIndex].name
        d.buttons = [GetString("connect"), GetString("delete_playlist"), GetString("cancel")]
        m.top.dialog = d
        m.top.dialog.observeFieldScoped("buttonSelected", "onPlaylistAction")
    else
        m.top.dialog.close = true
        if m.selectedPlaylistIndex = pList.Count() then showdialog()
    end if
end sub

sub onPlaylistAction()
    b = m.top.dialog.buttonSelected
    pList = getSavedPlaylists()
    p = pList[m.selectedPlaylistIndex]
    if b = 0
        activatePlaylist(p)
        reg = CreateObject("roRegistrySection", "profile")
        reg.Write("active_playlist_index", m.selectedPlaylistIndex.toStr())
        reg.Flush()
    elseif b = 1
        deletePlaylist(m.selectedPlaylistIndex)
    end if
    m.top.dialog.close = true
end sub

sub deletePlaylist(index as Integer)
    pList = getSavedPlaylists()
    if index < pList.Count()
        reg = CreateObject("roRegistrySection", "profile")
        pList.Delete(index)
        reg.Write("saved_playlists", FormatJson(pList))
        reg.Flush()
    end if
end sub

sub activatePlaylist(p as Object)
    reg = CreateObject("roRegistrySection", "profile")
    if p.type = "m3u"
        reg.Write("primaryfeed", p.url)
        reg.Delete("xtream_server")
        m.global.feedurl = p.url
        m.get_channel_list.control = "RUN"
    else
        reg.Write("xtream_server", p.server)
        reg.Write("xtream_user", p.user)
        reg.Write("xtream_pass", p.pass)
        loadXtreamContent()
    end if
    reg.Flush()
end sub

function getSavedPlaylists() as Object
    reg = CreateObject("roRegistrySection", "profile")
    if reg.Exists("saved_playlists") then return ParseJson(reg.Read("saved_playlists"))
    return []
end function

sub savePlaylist(p as Object)
    pList = getSavedPlaylists()
    pList.Push(p)
    reg = CreateObject("roRegistrySection", "profile")
    reg.Write("saved_playlists", FormatJson(pList))
    reg.Write("active_playlist_index", (pList.Count() - 1).toStr())
    reg.Flush()
end sub

sub showM3UDialog()
    k = createObject("roSGNode", "KeyboardDialog")
    k.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    k.title = GetString("m3u_url")
    k.buttons = [GetString("connect"), GetString("cancel")]
    m.top.dialog = k
    m.top.dialog.observeFieldScoped("buttonSelected", "onM3UKeyPress")
end sub

sub onM3UKeyPress()
    if m.top.dialog.buttonSelected = 0
        m.tempUrl = m.top.dialog.text
        askPlaylistName("m3u")
    else
        m.top.dialog.close = true
    end if
end sub

sub askPlaylistName(pType as String)
    m.tempType = pType
    k = createObject("roSGNode", "KeyboardDialog")
    k.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    k.title = UCase(GetString("playlist_name"))
    k.buttons = [UCase(GetString("next")), UCase(GetString("cancel"))]
    m.top.dialog = k
    m.top.dialog.observeFieldScoped("buttonSelected", "onNameEntered")
end sub

sub onNameEntered()
    if m.top.dialog.buttonSelected = 0
        name = m.top.dialog.text
        if name = "" then name = "Playlist"
        if m.tempType = "m3u"
            p = { name: name, type: "m3u", url: m.tempUrl }
        else
            reg = CreateObject("roRegistrySection", "profile")
            p = { name: name, type: "xtream", server: reg.Read("xtream_server"), user: reg.Read("xtream_user"), pass: reg.Read("xtream_pass") }
        end if
        savePlaylist(p)
    end if
    m.top.dialog.close = true
end sub

sub displayXtreamDialog(dialogStep as String)
    k = createObject("roSGNode", "KeyboardDialog")
    k.backgroundUri = "pkg:/images/rsgde_dlg_bg_hd.9.png"
    k.id = dialogStep
    title = ""
    if dialogStep = "server" then title = GetString("server_url")
    if dialogStep = "user" then title = GetString("username")
    if dialogStep = "pass" then title = GetString("password")
    k.title = UCase(title)
    k.buttons = [UCase(GetString("next")), UCase(GetString("cancel"))]
    m.top.dialog = k
    m.top.dialog.observeFieldScoped("buttonSelected", "onXtreamKeyPress")
end sub

sub onXtreamKeyPress()
    b = m.top.dialog.buttonSelected
    s = m.top.dialog.id
    t = m.top.dialog.text
    m.top.dialog.close = true
    if b = 0
        reg = CreateObject("roRegistrySection", "profile")
        if s = "server" then reg.Write("xtream_server", t) : displayXtreamDialog("user")
        if s = "user" then reg.Write("xtream_user", t) : displayXtreamDialog("pass")
        if s = "pass" then reg.Write("xtream_pass", t) : askPlaylistName("xtream")
        reg.Flush()
    end if
end sub

sub loadXtreamContent()
    reg = CreateObject("roRegistrySection", "profile")
    server = reg.Read("xtream_server")
    print "--- loadXtreamContent: Server from registry: "; server
    m.xtream_task.server = server
    m.xtream_task.username = reg.Read("xtream_user")
    m.xtream_task.password = reg.Read("xtream_pass")
    m.xtream_task.action = "all"
    m.xtream_task.control = "RUN"
    m.loadingIndicator.visible = true
    print "--- loadXtreamContent: Task triggered"
end sub

function GetString(key as String) as String
    if m.translations = invalid or m.translations.Count() = 0 then loadTranslations()
    if m.translations.DoesExist(key) then return m.translations[key]
    return key
end function

sub loadTranslations()
    m.translations = {}
    deviceInfo = CreateObject("roDeviceInfo")
    locale = deviceInfo.GetCurrentLocale()
    print "--- loadTranslations: Detected locale: "; locale
    
    ' Default paths to try
    paths = [
        "pkg:/locale/" + locale + "/translations.xml",
        "pkg:/locale/pt_BR/translations.xml",
        "pkg:/locale/en_US/translations.xml"
    ]
    
    xmlString = ""
    for each path in paths
        content = ReadAsciiFile(path)
        if content <> ""
            xmlString = content
            exit for
        end if
    end for
    
    if xmlString <> ""
        xml = CreateObject("roXMLElement")
        if xml.Parse(xmlString)
            if xml.file <> invalid and xml.file.body <> invalid
                units = xml.file.body.GetNamedElements("trans-unit")
                for each unit in units
                    id = unit@id
                    if id <> ""
                        target = ""
                        ' GetText() on roXMLList returns text of first matches child
                        if unit.target <> invalid then target = unit.target.GetText()
                        if target = "" and unit.source <> invalid then target = unit.source.GetText()
                        if target <> "" then m.translations[id] = target
                    end if
                end for
            end if
        end if
    end if
    print "--- loadTranslations: Loaded "; m.translations.Count(); " items"
end sub