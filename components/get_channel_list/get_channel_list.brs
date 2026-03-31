sub init()
	m.top.functionName = "executeTask"
end sub

sub executeTask()
    action = m.top.action
    if action = "get_group"
        loadGroupChannels()
    else
        loadAllGroups()
    end if
end sub

sub loadAllGroups()
	feedurl = m.top.url
    if feedurl = "" then feedurl = m.global.feedurl
    if feedurl = "" or feedurl = invalid then return

    ba = CreateObject("roByteArray")
    ba.FromAsciiString(feedurl)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    urlHash = digest.Process(ba)
    
    manifestPath = "tmp:/" + urlHash + "_manifest.json"
    tempFilePath = "tmp:/" + urlHash + "_download.m3u"
    fs = CreateObject("roFileSystem")

    ' --- CACHE INSTANTÂNEO ---
    if fs.Exists(manifestPath)
        contentStr = ReadAsciiFile(manifestPath)
        if contentStr <> ""
            manifest = ParseJson(contentStr)
            if manifest <> invalid and manifest.Count() > 0
                createNodesFromManifest(manifest)
                m.top.log_message = ""
                return
            end if
        end if
    end if

    cleanupTmpFiles()

    ' PHASE 1: DOWNLOAD
    m.top.log_message = "Fazendo download..."
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(feedurl)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.EnablePeerVerification(false)
    ut.EnableHostVerification(false)
    ut.EnableEncodings(true)
    ut.AddHeader("User-Agent", "Mozilla/5.0")
    
    port = CreateObject("roMessagePort")
    ut.SetMessagePort(port)
    
    if ut.AsyncGetToFile(tempFilePath)
        while true
            msg = wait(1000, port)
            if type(msg) = "roUrlEvent"
                code = msg.GetResponseCode()
                if code >= 200 and code < 300 then exit while
                m.top.log_message = "Erro de Download: " + code.toStr()
                return
            elseif msg = invalid
                if fs.Exists(tempFilePath)
                    info = fs.Stat(tempFilePath)
                    if info <> invalid
                        m.top.log_message = "Baixando: " + (info.size/1048576.0).FormatStr("%.1f") + " MB"
                    end if
                end if
            end if
        end while
    end if

    ' PHASE 2: PARSE (Stream large files in chunks to avoid memory limits)
    m.top.log_message = "Organizando canais..."
    m.groupsList = []     
    m.groupsMap = {}       
    m.groupBuffer = {}    
    m.rootNode = CreateObject("roSGNode", "ContentNode")
    m.top.content = m.rootNode
    m.parserState = { inExtinf: false, title: "Untitled", group: "Uncategorized" }

    ' Stream large file in chunks instead of loading all at once
    fileStream = CreateObject("roReadFile", tempFilePath)
    if fileStream <> invalid
        buffer = ""
        chunkSize = 65536 ' 64KB chunks
        
        while not fileStream.IsEOF()
            chunk = fileStream.ReadBlock(chunkSize)
            if chunk <> invalid and chunk.Count() > 0
                ' Convert bytes to string
                chunkStr = chunk.ToAsciiString()
                buffer = buffer + chunkStr
                
                ' Process complete lines from buffer
                while true
                    lineEnd = buffer.Instr(0, Chr(10))
                    if lineEnd < 0 then exit while
                    
                    line = Left(buffer, lineEnd).Trim()
                    buffer = Mid(buffer, lineEnd + 1)
                    
                    if line <> "" then parseLine(line)
                end while
                
                ' Update progress
                if fileStream.Tell() > 0
                    percent = Int((fileStream.Tell() * 100) / fileStream.Size())
                    m.top.log_message = "Processando: " + percent.ToStr() + "%"
                end if
            end if
        end while
        
        ' Process any remaining data in buffer
        if buffer <> ""
            lines = buffer.Split(Chr(10))
            for each line in lines
                if line.Trim() <> "" then parseLine(line.Trim())
            end for
        end if
        
        fileStream.Close()
        
        ' Flush any remaining buffered channels
        for each groupId in m.groupBuffer
            flushBuffer(groupId)
        end for
        
        ' Sync discovered groups with UI
        for i = 0 to m.groupsList.Count() - 1
            g = m.groupsList[i]
            node = m.rootNode.CreateChild("ContentNode")
            node.title = g.title
            node.id = "m3u_" + g.id
            node.contentType = "SECTION"
        end for
        
        print "--- M3U Parse Complete: "; m.groupsList.Count(); " groups, "; m.rootNode.getChildCount(); " total items"
    else
        print "!!! Failed to open file for streaming: "; tempFilePath
    end if
    
    ' Save manifest
    WriteAsciiFile(manifestPath, FormatJson(m.groupsList))
    m.top.log_message = ""
    
    if fs.Exists(tempFilePath) then fs.Delete(tempFilePath)
end sub

sub parseChunk(text as String)
    currPos = 0
    textLen = text.Len()
    while currPos < textLen
        nextPos = text.Instr(chr(10), currPos)
        if nextPos = -1 then nextPos = textLen
        line = text.Mid(currPos, nextPos - currPos).Trim()
        currPos = nextPos + 1
        if line <> "" then parseLine(line)
    end while
end sub

sub parseLine(line as String)
    if line.Left(7) = "#EXTINF" or line.Left(7) = "#extinf"
        m.parserState.inExtinf = true
        commaPos = line.InstrRev(",")
        if commaPos > 0 then m.parserState.title = line.Mid(commaPos + 1).Trim()
        groupPos = line.Instr("group-title=")
        if groupPos > 0
            sQ = line.Instr(groupPos, chr(34))
            if sQ > 0
                eQ = line.Instr(sQ + 1, chr(34))
                if eQ > 0 then m.parserState.group = line.Mid(sQ + 1, eQ - sQ - 1)
            end if
        end if
    elseif line.Left(1) <> "#" and m.parserState.inExtinf
        name = m.parserState.group
        id = getGroupId(name)
        
        if not m.groupsMap.DoesExist(id)
            m.groupsMap[id] = 0
            m.groupsList.Push({ title: name, id: id })
            m.groupBuffer[id] = []
        end if
        
        m.groupBuffer[id].Push([m.parserState.title, line])
        
        if m.groupBuffer[id].Count() >= 100
            flushBuffer(id)
        end if
        m.parserState.inExtinf = false
    end if
end sub

sub flushBuffer(id as String)
    idx = m.groupsMap[id]
    filename = "tmp:/grp_" + id + "_" + idx.toStr() + ".json"
    WriteAsciiFile(filename, FormatJson(m.groupBuffer[id]))
    m.groupsMap[id] = idx + 1
    m.groupBuffer[id] = []
end sub

sub cleanupTmpFiles()
    fs = CreateObject("roFileSystem")
    listing = fs.GetDirectoryListing("tmp:/")
    for each f in listing
        if f.Instr("grp_") >= 0 or f.Instr("_manifest.json") >= 0 then fs.Delete("tmp:/" + f)
    end for
end sub

sub createNodesFromManifest(groupsList as Object)
    rootNode = CreateObject("roSGNode", "ContentNode")
    for each g in groupsList
        node = rootNode.CreateChild("ContentNode")
        node.title = g.title
        node.id = "m3u_" + g.id
        node.contentType = "SECTION"
    end for
    m.top.content = rootNode
end sub

sub loadGroupChannels()
    groupId = m.top.group_id
    if groupId = "" return
    rootNode = CreateObject("roSGNode", "ContentNode")
    idx = 0
    fs = CreateObject("roFileSystem")
    while true
        f = "tmp:/grp_" + groupId + "_" + idx.toStr() + ".json"
        if not fs.Exists(f) exit while
        content = ReadAsciiFile(f)
        if content <> ""
            data = ParseJson(content)
            if data <> invalid
                for each item in data
                    node = rootNode.CreateChild("ContentNode")
                    node.title = item[0]
                    node.url = item[1]
                    node.contentType = "LIVE" 
                end for
            end if
        end if
        idx = idx + 1
    end while
    m.top.group_content = rootNode
end sub

function getGroupId(groupName as String) as String
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(groupName)
    digest = CreateObject("roEVPDigest")
    digest.Setup("md5")
    return digest.Process(ba)
end function
