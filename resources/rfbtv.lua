-- 
--  A dissector for ActiveVideo's CloudTV RFB-TV Protocol
--
--  version 1.3.0.0
--
--  Note: 
--  =====
--     The first 3 digits of the version is the RFB-TV protocol version supported.
--     The last digit is the dissector version that supports that version of protocol.
-- 

-- Tips on buffer / bitfield use
-- =============================
--   buffer(a,b):bitfield(c,d)
--     a = byte offset into buffer
--     b = # bytes [max=4]
--     c = bit offset [max=31]
--     d = # bits [max=32]

local consoleLogOn = false
local consoleLogMenuText = "Toggle RFBTV Dissector Console Logging"

local function toggleConsoleLogging() 
	if consoleLogOn then 
		consoleLogOn = false
	else 
		consoleLogOn = true
	end
end

register_menu(consoleLogMenuText, toggleConsoleLogging, MENU_TOOLS_UNSORTED)

-- local bit = require("bit")

local save_pictures = true 
local save_pictures_path = "/tmp"

do
	local info_string = ""
	local last_button = {}
	p = Proto("rfbtv","RFBTV")

	-- 
	-- You can change/add ports to interpret as server ports.
	-- Example
	-- local server_ports = { 8095, 1234, 5555, 8888 }
	-- 
	local server_ports = { 8095 }
	
	local audio_codecs = {
		[0] = "MPEG audio",
		[1] = "AAC",
		[2] = "AC3"
	}

	local video_codecs = {
		[0] = "AVC",
		[1] = "MPEG2",
	}

	local server_message_type = {
		[0] = "FramebufferUpdate",
		[1] = "SetColourMapEntries",
		[2] = "Bell",
		[3] = "ServerCutText",
		[16] = "SessionSetupResponse",
		[17] = "SessionTerminateRequest",
		[18] = "Ping",
		[19] = "StreamSetup",
		[20] = "MPEGdata",
		[21] = "PassThrough",
		[22] = "ServerCommand",
		[23] = "HandoffRequest",
		[26] = "CdmInitiateSessionRequest",
		[27] = "CdmAddLicenseRequest",
		[28] = "CdmActionRequest",
		[29] = "CdmStopSessionRequest",
		[30] = "CdmStopSessionConfirm"
	}

	local client_message_type = {
		[0] = "SetPixelFormat",
		[2] = "SetEncodings",
		[3] = "FramebufferUpdateRequest",
		[4] = "KeyEvent",
		[5] = "PointerEvent",
		[6] = "ClientCutText",
		[16] = "PlaybackReport",
		[17] = "SessionTerminateIndication",
		[18] = "SessionSetup",
		[19] = "StreamConfirm",
		[20] = "StreamSetupResponse",
		[21] = "Pong",
		[22] = "InputEvent",
		[23] = "PassThrough",
		[24] = "Properties",
		[31] = "CdmInitiateSessionResponse",
		[32] = "CdmAddLicenseResponse",
		[33] = "CdmAddLicenseIndication",
		[34] = "CdmActionUpdate",
		[35] = "CdmStopSessionIndication"
	}

	local encoding_types = {
		[42] = "picture-object",
		[43] = "URL",
		[44] = "MPEG-TS-HTTP",
		[45] = "MPEG-TS-embed"
	}

	local stream_setup_response_codes = {
		[0]  = "success",
		[20] = "cable tuning error",
		[21] = "unable to open IP resource",
		[22] = "unsupported URI scheme"
	}

	local stream_confirm_codes = {
		[0]  = "success", 
		[30] = "failed to descramble stream",
		[31] = "failed to decode stream",
		[32] = "no transport stream with the indicated TSID was found", 
		[33] = "no network with the indicated NID was found",
		[34] = "no program with the indicated PID was found",
		[35] = "unrecoverable error at the physical layer",
		[36] = "unspecified error (if no other applies)"
	}
	
	local session_termination_indication_codes = {
		[0] = "normal session end"
	}

	local result_codes = {
		[0] = "OK",
		[1] = "redirect to the specified URI",
		[2] = "client id missing or not understood",
		[3] = "specified application not found",
		[4] = "internal server configuration error",
		[5] = "no resources to support session",
		[6] = "unspecified error",
		[7] = "application not found",
		[8] = "insufficient or invalid parameters",
		[9] = "internal server execution error"
	}

	local session_terminate_request_codes = {
		[0]  = "normal session end",
		[10] = "insufficient bandwidth",
		[11] = "latency too large",
		[12] = "suspend session",
		[13] = "unspecified error",
		[14] = "do not retune",
		[15] = "ping timeout",
		[16] = "internal server execution error",
		[17] = "server is shutting down",
		[18] = "failed to setup application stream"
	}

	local rfbtv_keys = {
		[0x30] = "0",
		[0x31] = "1",
		[0x32] = "2",
		[0x33] = "3",
		[0x34] = "4",
		[0x35] = "5",
		[0x36] = "6",
		[0x37] = "7",
		[0x38] = "8",
		[0x39] = "9",
		[0x00000041] = "A",
		[0x00000042] = "B",
		[0x00000043] = "C",
		[0x00000044] = "D", 
		[0xff51] = "left",
		[0xff52] = "up",
		[0xff53] = "right",
		[0xff54] = "down",
		[0xff55] = "page up",
		[0xff56] = "page down",
		[0xff95] = "home",
		[0x10000000] = "ok",
		[0x10000001] = "back",
		[0x10000010] = "play",
		[0x10000011] = "stop",
		[0x10000012] = "pause",
		[0x10000013] = "fast forward",
		[0x10000014] = "rewind",
		[0x10000015] = "skip forward",
		[0x10000016] = "replay",
		[0x10000017] = "playpause",
		[0x10000020] = "next",
		[0x10000021] = "prev",
		[0x10000022] = "end",
		[0x10000023] = "list",
		[0x10000024] = "last",
		[0x10000030] = "home",
		[0x10000031] = "exit",
		[0x10000032] = "menu",
		[0x10000033] = "net tv",
		[0x10000034] = "top menu",
		[0x10000035] = "on demand",
		[0x10000036] = "pvr",
		[0x10000037] = "live",
		[0x10000038] = "media",
		[0x10000039] = "settings",
		[0x10000040] = "channel up",
		[0x10000041] = "channel down",
		[0x10000050] = "red",
		[0x10000051] = "green",
		[0x10000052] = "yellow",
		[0x10000053] = "blue",
		[0x10000054] = "oem A",
		[0x10000055] = "oem B",
		[0x10000056] = "oem C",
		[0x10000057] = "oem D",
		[0x10000060] = "info",
		[0x10000061] = "help",
		[0x10000070] = "record",
		[0x10000080] = "epg",
		[0x10000081] = "favorites",
		[0x10000082] = "day up", 
		[0x10000083] = "day down",
		[0x10000090] = "mute",
		[0x10000091] = "volume down", 
		[0x10000092] = "volume up"
	}

	local rfbtv_pointer = {
		[0x0] = "",
		[0x1] = "left button ",
		[0x2] = "middle button ",
		[0x3] = "left and middle buttons ",
		[0x4] = "right button ",
		[0x5] = "left and right buttons ",
		[0x7] = "left, middle, and right buttons ",
		[0x8] = "wheel roll ",
		[0x9] = "wheel roll and left button ",
		[0xa] = "wheel roll and middle button ",
		[0xb] = "wheel roll, with left and middle buttons ",
		[0xd] = "wheel roll, with left and right buttons ",
		[0xe] = "wheel roll, with right and middle buttons ",
		[0xf] = "wheel roll, with left, middle, and right buttons ",
		[0x10] = "wheel roll ",
		[0x12] = "wheel roll and middle button ",
	}

	--
	-- Client buffer/frame handling functions
	--

	local function client_handle_session_setup(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: SessionSetup")
		local args = buffer(1,1):uint()
		local offset = 2
		local index = 1
		while args > 0 do
			local len = tonumber(buffer(offset,2):uint())
			local tag = buffer(offset+2,len):string()
			offset = offset + 2 + len
			len = tonumber(buffer(offset,2):uint())
			local val = buffer(offset+2,len):string()
			subtree:add(buffer(offset+2,len), "Parameter " .. index .. ": " .. tag .. " = " .. val .. " (len: " .. len .. ")")
			info_string = string.format("%s, %s=%s", info_string, tag, val)
			offset = offset + 2 + len
			index = index + 1
			args = args - 1
		end
		local client_ip_port = string.format("%s:%s", tostring(pinfo.src), tostring(pinfo.src_port))
		last_button[client_ip_port] = 0		
		return offset
	end

	local function client_handle_set_encodings(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: SetEncodings")
		local args = buffer(2,2):uint()
		local index = 1
		local offset = 4
		while args > 0 do
			local t = buffer(offset,4):int()
			local t_str = encoding_types[t] or "unknown"
			subtree:add(buffer(offset,4), "Encoding type " .. t .. " " .. t_str)
			info_string = string.format("%s, type %s=%s", info_string, t, t_str)
			offset = offset + 4
			index = index + 1
			args = args - 1
		end
		return offset
	end

	local function client_handle_framebuffer_update_request(buffer, subtree)
		local incremental = buffer(1,1):uint()
		if incremental == 0 then
			incremental = "false"
		else 
			incremental = "true"
		end
		local x = buffer(2,2):uint()
		local y = buffer(4,2):uint()
		local w = buffer(6,2):uint()
		local h = buffer(8,2):uint()

		subtree:add(buffer(0, 1), "RFBTV client message: FramebufferUpdateRequest")
		subtree:add(buffer(1, 1), "Incremental: " .. incremental)
		subtree:add(buffer(2, 8), "Rectangle (x:y:w:h): " .. x .. ":" .. y .. ":" .. w .. ":" .. h)
		info_string = string.format("%s, incremental:%s, rect(x:%s, y:%s, w:%s, h:%s)", info_string, incremental, x, y, w, h)

		return 10
	end

	local function client_handle_stream_setup_response(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: StreamSetupResponse")
		local result = buffer(1, 1):uint()
		local result_str = stream_setup_response_codes[result] or "unknown"
		subtree:add(buffer(1, 1), "Result : " .. result .. " " .. result_str)
		local parameter_len = buffer(2,2):uint()
		subtree:add(buffer(4, parameter_len), "Parameter: " .. buffer(4, parameter_len):string())
		info_string = string.format("%s, %s=%s", info_string, result, result_str)
		return 4 + parameter_len
	end

	local function client_handle_stream_confirm(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: StreamConfirm")
		local result = buffer(1, 1):uint()
		local result_str = stream_confirm_codes[result] or "unknown"
		subtree:add(buffer(1, 1), "Result : " .. result .. " " .. result_str)
		info_string = string.format("%s, %s=%s", info_string, result, result_str)
		return 2
	end


	local function client_handle_session_terminate_indication(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: SessionTerminateIndication")
		local result = buffer(1, 1):uint()
		local result_str = session_termination_indication_codes[result] or "unknown"
		subtree:add(buffer(1, 1), "Result : " .. result .. " " .. result_str)
		info_string = string.format("%s, %s=%s", info_string, result, result_str)
		local client_ip_port = string.format("%s:%s", tostring(pinfo.src), tostring(pinfo.src_port))
		last_button[client_ip_port] = 0
		return 2
	end

	local function client_handle_key_event(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: KeyEvent")
		local down = buffer(1, 1):uint()
		local key = buffer(4, 4):uint()
		if down ~= 0 then
			down = "true"
		else 
			down = "false"
		end
		subtree:add(buffer(1, 1), "Down-flag: " .. down)
		local key_str = rfbtv_keys[key] or "unknown"
		local key_display = string.format("KeyValue: 0x%x=%d(decimal), KeyName=%s", key, key, key_str)
		subtree:add(buffer(4, 4), key_display)
		info_string = string.format("%s, keydown=%s, %s", info_string, down, key_display)
		return 8
	end


	local function client_handle_pointer_event(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: PointerEvent")
		local button = buffer(1, 1):uint()
		local button_str = rfbtv_pointer[button]
		local pointer_event = ""
		local x_coord = buffer(2, 2):uint()
		local y_coord = buffer(4, 2):uint()
		local client_ip_port = string.format("%s:%s", tostring(pinfo.src), tostring(pinfo.src_port))
		if last_button[client_ip_port] == nil then
		   last_button[client_ip_port] = 0
		end
		
		if (button ~= 0 and last_button[client_ip_port] ~= 0) then -- this is a button down move event
		   pointer_event = "event: move with " .. button_str .. "down"
		   subtree:add(buffer(1, 1), pointer_event)
		   info_string = string.format("%s, %s, x: %s, y: %s", info_string, pointer_event, x_coord, y_coord)
        else 
		   if (button ~= 0 and last_button[client_ip_port] == 0) then -- this is a pointer button down, wheel roll event
		      if button == 0x8 then -- wheel roll up
		         pointer_event = "up"
			  else
			     pointer_event = "down"
			  end
		   else
		      if (button == 0 and last_button[client_ip_port] ~= 0) then -- this is a pointer button up or wheel roll event
				 button_str = rfbtv_pointer[last_button[client_ip_port]]
    	         if (button_str == "wheel roll " and last_button[client_ip_port] == 0x10) then -- wheel roll down
		            pointer_event = "down"
			     else
			        pointer_event = "up"
			     end
			  else
			     pointer_event = "move"
		      end
	       end
		   subtree:add(buffer(1, 1), "event: " .. button_str .. pointer_event)
		   info_string = string.format("%s, %s%s, x: %s, y: %s", info_string, button_str, pointer_event, x_coord, y_coord)
		end
		subtree:add(buffer(2, 2), "x: " .. x_coord)
		subtree:add(buffer(4, 2), "y: " .. y_coord)
				
		if button ~= 0 then
		   last_button[client_ip_port] = button
		else
		   last_button[client_ip_port] = 0
		end
		return 6
	end

	local function client_handle_cdm_initiate_session_response(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: CdmInitiateSessionResponse")
		local offset = 1
		local result = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "result:" .. result)
		offset = offset + 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local asset_id_len = buffer(offset, 2):uint()
		local asset_id_tree = subtree:add(buffer(offset, 2 + asset_id_len), "AssetID")
		asset_id_tree:add(buffer(offset, 2), "length:" .. asset_id_len)
		offset = offset + 2
		local asset_id = buffer(offset, asset_id_len):string()
		asset_id_tree:add(buffer(offset, asset_id_len), "value:" .. asset_id)
		offset = offset + asset_id_len
		local laurl_id_len = buffer(offset, 2):uint()
		local laurl_id_tree = subtree:add(buffer(offset, 2 + laurl_id_len), "LAURL")
		laurl_id_tree:add(buffer(offset, 2), "length:" .. laurl_id_len)
		offset = offset + 2
		local laurl_id = buffer(offset, laurl_id_len):string()
		laurl_id_tree:add(buffer(offset, laurl_id_len), "value:" .. laurl_id)
		offset = offset + laurl_id_len
		local lic_req_body_len = buffer(offset, 2):uint()
		local lic_req_body_tree = subtree:add(buffer(offset, 2 + lic_req_body_len), "License Request Body")
		lic_req_body_tree:add(buffer(offset, 2), "length:" .. lic_req_body_len)
		offset = offset + 2
		local lic_req_body = buffer(offset, lic_req_body_len)
		lic_req_body_tree:add(buffer(offset, lic_req_body_len), "value:" .. lic_req_body)
		offset = offset + lic_req_body_len
		return offset
	end

	local function client_handle_cdm_add_license_response(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: CdmAddLicenseResponse")
		local offset = 1
		local result = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "result:" .. result)
		offset = offset + 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local ack_body_len = buffer(offset, 2):uint()
		local ack_body_tree = subtree:add(buffer(offset, 2 + ack_body_len), "Ack Body")
		ack_body_tree:add(buffer(offset, 2), "length:" .. ack_body_len)
		offset = offset + 2
		local ack_body = buffer(offset, ack_body_len)
		ack_body_tree:add(buffer(offset, ack_body_len), "value:" .. ack_body)
		offset = offset + ack_body_len
		return offset
	end

	local function client_handle_cdm_add_license_indication(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: CdmAddLicenseIndication")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local asset_id_len = buffer(offset, 2):uint()
		local asset_id_tree = subtree:add(buffer(offset, 2 + asset_id_len), "AssetID")
		asset_id_tree:add(buffer(offset, 2), "length:" .. asset_id_len)
		offset = offset + 2
		local asset_id = buffer(offset, asset_id_len):string()
		asset_id_tree:add(buffer(offset, asset_id_len), "value:" .. asset_id)
		offset = offset + asset_id_len
		local nr_licenses = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "nr_licenses:" .. nr_licenses)
		offset = offset + 1
		if nr_licenses > 0 then
			local subtree = subtree:add(buffer(offset, tlv_length), "LID's")
			local index = 0
			while nr_licenses > 0 do
				local license_id_len = buffer(offset, 2):uint()
				local license_id_tree = subtree:add(buffer(offset, 2 + license_id_len), "LID[" .. index .. "]")
				license_id_tree:add(buffer(offset, 2), "length:" .. license_id_len)
				offset = offset + 2
				local license_id = buffer(offset, license_id_len):string()
				license_id_tree:add(buffer(offset, license_id_len), "value:" .. license_id)
				offset = offset + license_id_len
				index = index + 1
				nr_licenses = nr_licenses - 1
			end
		end
		return offset
	end

	local function client_handle_cdm_action_update(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: CdmActionUpdate")
		local offset = 1
		local result = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "result:" .. result)
		offset = offset + 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local lid_len = buffer(offset, 2):uint()
		local lid_tree = subtree:add(buffer(offset, 2 + lid_len), "LID")
		lid_tree:add(buffer(offset, 2), "length:" .. lid_len)
		offset = offset + 2
		local lid = buffer(offset, lid_len):string()
		lid_tree:add(buffer(offset, lid_len), "value:" .. lid)
		offset = offset + lid_len
		local stop_token_len = buffer(offset, 2):uint()
		local stop_token_tree = subtree:add(buffer(offset, 2 + stop_token_len), "Secure Stop Token")
		stop_token_tree:add(buffer(offset, 2), "length:" .. stop_token_len)
		offset = offset + 2
		local stop_token = buffer(offset, stop_token_len)
		stop_token_tree:add(buffer(offset, stop_token_len), "value:" .. stop_token)
		offset = offset + stop_token_len
		return offset
	end

	local function client_handle_cdm_stop_session_indication(buffer, pinfo, subtree)
		subtree:add(buffer(0, 1), "RFBTV client message: CdmStopSessionIndication")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local reason = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "reason:" .. reason)
		offset = offset + 1
		local signed_stop_len = buffer(offset, 2):uint()
		local signed_stop_tree = subtree:add(buffer(offset, 2 + signed_stop_len), "Signed Secure Stop")
		signed_stop_tree:add(buffer(offset, 2), "length:" .. signed_stop_len)
		offset = offset + 2
		local signed_stop = buffer(offset, signed_stop_len)
		signed_stop_tree:add(buffer(offset, signed_stop_len), "value:" .. signed_stop)
		offset = offset + signed_stop_len
		return offset
	end

	--
	-- Server buffer/frame handling functions
	--

	local function server_handle_server_command_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: ServerCommand")
		return 1
	end

	local function server_handle_handoff_request_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: HandoffRequest")
		return 1
	end

	local function server_handle_cdm_initiate_session_request_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: CdmInitiateSessionRequest")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = 3
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len
		local drm_type = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "DrmType:" .. drm_type)
		offset = offset + 1
		local nr_initdata_tlvs = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "nr-initdata-tlvs:" .. nr_initdata_tlvs)
		offset = offset + 1
		local tlv_length = buffer:len() - offset;
		if tlv_length > 0 then
			local subtree = subtree:add(buffer(offset, tlv_length), "TLV's")
			local index = 0
			while nr_initdata_tlvs > 0 do
				nr_initdata_tlvs = nr_initdata_tlvs - 1
				local tlv_type = tonumber(buffer(offset, 1):uint())
				local tlv_tree = subtree:add(buffer(offset, 1), "type:" .. tlv_type)
				offset = offset + 1
				if tlv_type == 48 then
					local len = tonumber(buffer(offset, 2):uint())
					offset = offset + 2
					local rights = buffer(offset, len):string()
					tlv_tree:add(buffer(offset, len), "TLV[" .. index .. "]: rights = " .. rights)
					offset = offset + len
				elseif tlv_type == 49 then
					local is_ldl = buffer(offset, 1)
					tlv_tree:add(buffer(offset, 1), "TLV[" .. index .. "]: isLDL = " .. is_ldl)
					offset = offset + 1
				elseif tlv_type == 50 then
					local len = tonumber(buffer(offset, 2):uint())
					offset = offset + 2
					local drm_header = buffer(offset, len) -- do not convert to string, raw data
					tlv_tree:add(buffer(offset, len), "TLV[" .. index .. "]: DRM header = " .. drm_header)
					offset = offset + len
				else
					tlv_tree:add(buffer(offset, 1), "TLV[" .. index .. "]: UNKNOWN TYPE!")
					offset = offset + 1 -- just a guess
				end
				index = index + 1
			end
		end
		return offset;
	end

	local function server_handle_cdm_addlicense_request_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: CdmAddLicenseRequest")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len

		local license_resp_len = buffer(offset, 2):uint()
		local license_resp_tree = subtree:add(buffer(offset, 2 + license_resp_len), "License Response")
		license_resp_tree:add(buffer(offset, 2), "length:" .. license_resp_len)
		offset = offset + 2
		local license_resp = buffer(offset, license_resp_len) -- show as binary data
		license_resp_tree:add(buffer(offset, license_resp_len), "value:" .. license_resp)
		return offset + license_resp_len
	end

	local function server_handle_cdm_action_request_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: CdmActionRequest")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len

		local action_type_len = buffer(offset, 2):uint()
		local action_type_tree = subtree:add(buffer(offset, 2 + action_type_len), "Action Type")
		action_type_tree:add(buffer(offset, 2), "length:" .. action_type_len)
		offset = offset + 2
		local action_type = buffer(offset, action_type_len):string()
		action_type_tree:add(buffer(offset, action_type_len), "value:" .. action_type)
		return offset + action_type_len
	end

	local function server_handle_cdm_stop_session_request_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: CdmStopSessionRequest")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		offset = offset + session_id_len

		local reason = buffer(offset, 1):uint()
		subtree:add(buffer(offset, 1), "Reason: " .. reason)
		return offset + 1
	end

	local function server_handle_cdm_stop_session_confirm_message(buffer, subtree)
		subtree:add(buffer(0, 1), "RFBTV server message: CdmStopSessionConfirm")
		local offset = 1
		local session_id_len = buffer(offset, 2):uint()
		local session_id_tree = subtree:add(buffer(offset, 2 + session_id_len), "CdmSessionID")
		session_id_tree:add(buffer(offset, 2), "length:" .. session_id_len)
		offset = offset + 2
		local session_id = buffer(offset, session_id_len):string()
		session_id_tree:add(buffer(offset, session_id_len), "value:" .. session_id)
		return offset + session_id_len
	end

	local function server_handle_passthrough_message(buffer, subtree)
		local cmd_len = buffer(1,2):uint()
		local cmd_str = buffer(3,cmd_len):string()
		local msg_len = buffer(3+cmd_len,4):int()
		local msg_str = ""
		if cmd_str == "vodctrl" then
			local tmp = buffer(3+cmd_len+4,msg_len):uint()
			msg_str = tmp
			if tmp == 1 then msg_str = "Trickplay-Start" end
			if tmp == 2 then msg_str = "Trickplay-Stop" end
			if tmp == 3 then msg_str = "LowlatencyMode-On" end
			if tmp == 4 then msg_str = "LowlatencyMode-Off" end
		elseif cmd_str == "EMM" then
			msg_str = "EMM data"
		end
		subtree:add(buffer(0, 1), "RFBTV server message: PassThrough")
		subtree:add(buffer(3, cmd_len), "protocol-identifier: " .. cmd_str)
		subtree:add(buffer(3+cmd_len, 4), "message len: " .. msg_len) 
		subtree:add(buffer(3+cmd_len+4, msg_len), "message str: " .. msg_str) 
		info_string = string.format("%s, protocol-identifier:%s:, message len:%s, message str: %s", info_string, cmd_str, msg_len, msg_str)
		return 3+cmd_len+4+msg_len
	end

	local function server_handle_session_response_setup(buffer, pinfo, subtree)
		local result = buffer(1,1):uint()
		local result_str = result_codes[result] or "unknown"
		local session_id = buffer(2,4):uint()
		subtree:add(buffer(0, 1), "RFBTV server message: SessionSetupResponse")
		subtree:add(buffer(1, 1), "Result: " .. result .. " = " .. result_str)
		subtree:add(buffer(2, 4), "Session-ID: " .. session_id)
		info_string = string.format("%s, Result: %s=%s, Session-ID=%s", info_string, result, result_str, session_id)
		local redir_len = buffer(6,2):uint()
		subtree:add(buffer(6, 2), "Redir length: " .. redir_len)
		if redir_len ~= 0 then
			subtree:add(buffer(6+2, redir_len), "Redirect-URL: " .. buffer(6+2, redir_len):string())
			info_string = string.format("%s, Redirect-URL: %s", info_string, buffer(6+2, redir_len):string())
		end
		local cookie_len = buffer(6+2+redir_len, 2):uint()
		if cookie_len ~= 0 then
			if buffer:len() < cookie_len + 10 then
				local new_length = buffer:len() - 10
				local subtree = subtree:add(buffer(6+2, 2 + new_length), "Cookie")
				subtree:add(buffer(6+2, 2), "Cookie original length: " .. cookie_len .. " fixed length: " .. new_length)
				subtree = subtree:add(buffer(6+2+redir_len+2, new_length), "Cookie (length error): " .. buffer(6+2+redir_len+2, new_length):string())
				subtree:add(buffer(6+2+redir_len+2, new_length), " ERROR: not enough bytes in message: buffer length = " .. buffer:len())
				cookie_len = new_length
			else
				local subtree = subtree:add(buffer(6+2, 2 + cookie_len), "Cookie")
				subtree:add(buffer(6+2, 2), "Cookie length: " .. cookie_len)
				subtree:add(buffer(6+2+redir_len+2, cookie_len), "Cookie: " .. buffer(6+2+redir_len+2, cookie_len):string())
			end
			info_string = string.format("%s, Cookie: %s", info_string, buffer(6+2+redir_len+2, cookie_len):string())
		end
		local client_ip_port = string.format("%s:%s", tostring(pinfo.src), tostring(pinfo.src_port))
		last_button[client_ip_port] = 0
		return 6+2+redir_len+2+cookie_len
	end

	local function server_handle_framebuffer_update(buffer, pinfo, subtree)
		local debug = require "debug"
		local bitmask = buffer(1,1):uint()
		local flip = "false"
		local clear = "false"
		if bit.band(bitmask, 0x01) ~= 0 then flip = "true" end
		if bit.band(bitmask, 0x02) ~= 0 then clear = "true" end
		local rects = buffer(2,2):uint()
		--print("pkt: " .. pinfo.number .. " Get new framebuffer update with " .. rects .. " rectangles")
		local total_rects = rects
		local offset = 4
		local index = 1
		subtree:add(buffer(0, 1), "RFBTV server message: FrameBufferUpdate")
		subtree:add(buffer(1, 1), "Bitmask Flip : " .. flip)
		subtree:add(buffer(1, 1), "Bitmask Clear : " .. clear)
		subtree:add(buffer(2, 2), "Number of rects in this frame: " .. rects)
		info_string = string.format("%s, Bitmask Flip: %s, Bitmask Clear: %s, # rect in frame: %s", info_string, flip, clear, tostring(rects))
		local buffer_length = buffer:len()
		local excess_buffer = buffer_length - 4
		while rects > 0 do
			if buffer:len() < offset+13 then
				pinfo.desegment_offset = 0;
				pinfo.desegment_len = offset + 13
				if consoleLogOn then
					info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, total_rects: %d, offset: %d ==> buffer_len < offset + 12, with excess_buffer: %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer_length, pinfo.desegment_offset, pinfo.desegment_len, total_rects, offset, excess_buffer))
				end
				return buffer:len() 
			end
			local x = buffer(offset,2):uint()
			local y = buffer(offset+2,2):uint()
			local w = buffer(offset+4,2):uint()
			local h = buffer(offset+6,2):uint()
			local encoding_type = buffer(offset+8,4):uint()
			local encoding_type_str = encoding_types[encoding_type] or "unknown"
                
			local rectInfo = string.format("Rect #%d: x: %d, y: %d, w: %d, h: %d, encoding type: %s", index, x, y, w, h, encoding_type_str)
			subtree:add(buffer(offset, 12), rectInfo)
			offset = offset + 12
			if encoding_type == 42 then
				-- Picture type
				local alpha = buffer(offset, 1)
				local string_size = buffer(offset+1, 4):string()
				local size = buffer(offset+1, 4):uint()
				local first_byte = buffer(offset+5, 1):uint()
				local sec_byte = buffer(offset+6, 1):uint()
				local img_type = "unknown"
				if first_byte == 66 and sec_byte == 77 then img_type = "BMP" end
				if first_byte == 255 then img_type = "JPEG" end
				if first_byte == 137 then img_type = "PNG" end
				-- print("index", index, alpha, size, img_type) 
				rect_bytes_needed = size + offset + 5
				excess_buffer = buffer:len() - rect_bytes_needed
				subtree:add(buffer(offset, 5), "Picture type data: alpha=" .. alpha .. 
					" size=" .. size .. " type: " .. img_type)

				-- When there is not enough data yet let wireshark reassemble and call us again.			
				local packet_status = string.format("Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, FBU rects: %d, to include rect #%d -- bytes needed: %d, excess_buffer: %d ", pinfo.number, buffer_length, pinfo.desegment_offset, pinfo.desegment_len, total_rects, index, rect_bytes_needed, excess_buffer)

				local buffer_status = ""
				local rect_status = total_rects - index
				if excess_buffer == 0 then
					buffer_status = "=="
				elseif excess_buffer < 0 then
					buffer_status = "<"
					rect_status = total_rects - index + 1
				else
					buffer_status = ">"
				end
				
				if consoleLogOn then
					info(string.format("%s - %s ==> buffer %s rect_bytes_needed, #rects left: %d", debug.getinfo(1, "l").currentline, packet_status, buffer_status, rect_status))
				end
				
				if buffer:len() < rect_bytes_needed then
					if rects > 1 then
						pinfo.desegment_offset = 0
						pinfo.desegment_len = DESEGMENT_ONE_MORE_SEGMENT
						if consoleLogOn then
							info(string.format("%s - Pkt: %d, bufLen: %d, short by unknown #bytes, setting desegment_len = %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer_length, DESEGMENT_ONE_MORE_SEGMENT))
						end
					else
						pinfo.desegment_offset = 0;
						pinfo.desegment_len = -excess_buffer
						if consoleLogOn then
							info(string.format("%s - Pkt: %d, bufLen: %d, short by %d bytes", debug.getinfo(1, "l").currentline, pinfo.number, buffer_length, excess_buffer))
						end
					end
					--return size - buffer:len() + offset + 5 
					-- print("Reassemble need more bytes " .. pinfo.desegment_len) 
					return buffer:len() 
				end
				subtree:add(buffer(offset+5, size), "     Picture data: " .. buffer(offset+5, size))

				if save_pictures == true then
					local file_type = "raw"
					if img_type == "PNG" then
						file_type = "png"
					elseif img_type == "BMP" then
						file_type = "bmp"
					elseif img_type == "JPEG" then
						file_type = "jpg"
					end
					-- local fname = save_pictures_path .. 
					-- 	"/pkt-" .. pinfo.number ..
					--	"-rectnr-" .. index ..
					--	"-cordinates-" .. x .. "." .. y .. "." .. w .. "." .. h .. 
					--	"-alpha-" .. alpha ..
					--	"." .. file_type
					local fname = save_pictures_path ..
						"/overlay#" .. pinfo.number .. "-UTC=" .. tostring(pinfo.abs_ts) .. "-Flip=" ..flip.. " Clear="..clear .. " Rect=" .. index .. " Alpha=" .. alpha .. " Rects=" .. total_rects  .." Loc=" .. x .. "x" .. y .. " Size=" .. w .. "x" .. h .. "." .. file_type
					local fd = assert(io.open(fname, "w+b")) 
					if fd then
						local tt = 0 
						local lopt = size
						local value
						while lopt > 0 do
							value = buffer(offset+5+tt,1):uint()
							fd:write(string.char(value))
							tt = tt + 1
							lopt = lopt - 1
						end
						fd:flush()
						fd:close()
					end
				end				
				offset = rect_bytes_needed

			elseif encoding_type == 43 then
				local alpha = buffer(offset, 1)
				local uri_len = buffer(offset+1,2):uint()
				local uri_str = buffer(offset+1+2,uri_len):string()
				subtree:add(buffer(offset, 1), "URL data: alpha=" .. alpha)
				subtree:add(buffer(offset+1+2,uri_len) "URI=" .. uri_str)
				offset = offset + 1 + 2 + uri_len
			else
				subtree:add(buffer(offset), "Fixme add this type to disector... " .. buffer(offset))
			end

			index = index + 1
			rects = rects - 1
		end
		pinfo.desegment_offset = offset;
		pinfo.desegment_len = 0;
		if consoleLogOn then
			info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, total_rects: %d, offset: %d ==> FBU rects done, with excess_buffer: %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer_length, pinfo.desegment_offset, pinfo.desegment_len, total_rects, offset, excess_buffer))
		end
		return offset
	end

	local function server_handle_stream_setup(buffer, subtree)
                subtree:add(buffer(0, 1), "RFBTV server message: StreamSetup")
		local w = buffer(1, 2):uint()
		local h = buffer(3, 2):uint()
		local ac = buffer(5, 1):uint()
		local ac_str = audio_codecs[ac] or "unknown"
		local vc = buffer(6, 1):uint()
		local vc_str = video_codecs[vc] or "unknown"
                subtree:add(buffer(1, 6), "Stream size WxH: " .. w .. "x" .. h .. " acodec: " .. ac_str .. " vcodec: " .. vc_str)
		local uri_len = buffer(7,2):uint()
                subtree:add(buffer(9,uri_len), "URI: " .. buffer(9,uri_len):string() .. " (len: " .. uri_len .. ")")
		info_string = string.format("%s, stream WxH: %s x %s, acodec: %s, vcodec: %s, URI: %s", info_string, w, h, ac_str, vc_str, buffer(9,uri_len):string())
		return 9+uri_len
	end

	local function server_handle_session_terminate_request(buffer, pinfo, subtree)
        subtree:add(buffer(0, 1), "RFBTV server message: SessionTerminateRequest")
		local result = buffer(1,1):uint()
		local result_str = session_terminate_request_codes[result] or "unknown"
                subtree:add(buffer(1, 1), "Result: " .. result .. " = " .. result_str)
		info_string = string.format("%s, %s=%s", info_string, result, result_str)
		local client_ip_port = string.format("%s:%s", tostring(pinfo.src), tostring(pinfo.src_port))
		last_button[client_ip_port] = 0
		return 2
	end


	--
	-- Register the dissector handler.
	--

	function p.dissector(buffer,pinfo,tree)
		local debug = require "debug"
		local function update_buffer(pinfo, buffer, byte_count)
			if buffer:len() > byte_count then 
				if consoleLogOn then
					info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, byte_count: %d, returning buffer size: %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len, byte_count, buffer:len()-byte_count))
				end
				return buffer(byte_count, buffer:len() - byte_count)
			end
			if buffer:len() <= byte_count then 
				if consoleLogOn then
					info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, byte_count: %d, returning buffer=nil", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len, byte_count))
				end
				return nil
			else
				pinfo.desegment_offset = 0
				pinfo.desegment_len = DESEGMENT_ONE_MORE_SEGMENT	
				if consoleLogOn then
					info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, byte_count: %d, returning buffer size: %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len, byte_count, buffer:len()-byte_count))
				end
				return buffer(byte_count, buffer:len() - byte_count)
			end
		end
		
		if consoleLogOn then
			info(string.format("%s - Pkt: %d, Src IP: %s, Src Port: %s, bufLen: %d, desegment_offset: %d, desegment_len: %d", debug.getinfo(1, "l").currentline, pinfo.number, tostring(pinfo.src), tostring(pinfo.src_port), buffer:len(), pinfo.desegment_offset, pinfo.desegment_len))
		end
	
		if pinfo.desegment_offset ~= 0 then
			local subtree = tree:add(p, buffer(), "RFBTV MORE DATA...")
			if consoleLogOn then
				info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d ", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len))
			end
			return
		end

		local protocol = "RFBTV"
		pinfo.cols.protocol = protocol

		-- Set type to client when send from port 8095 it's a server
		local msg_sender = "client"
		for _,port in pairs(server_ports) do
			if pinfo.src_port == port then
				msg_sender = "server"
			end
		end

		local msg_name = "unknown"
		local subtree_name = string.format("%s", protocol)

		if buffer(0,1):string() == 'R' then -- this is a "Start version" packet
			msg_name = "Start version"
			version_str = string.sub(buffer(0):string(), 1, string.len(buffer(0):string())-1) -- remove trailing '\n'
			info_string = string.format("%s %s %s", msg_sender, msg_name, version_str)
			subtree_name = string.format("%s %s: ", subtree_name, msg_name)
			subtree = tree:add(p, buffer(), subtree_name)
			subtree:add(buffer(0), subtree_name .. version_str) -- RFB-TV 001.001
		else
			info_string=""
			while buffer and buffer:len() > 0 do
				local msg_byte_count = nil
				local msg_key = buffer(0,1):uint()
				local subtree = ""
				if string.len(info_string) > 0 then
					info_string = string.format("%s; ", info_string)
				end
				if msg_sender == "client" then
					msg_name = client_message_type[msg_key] or "unknown"
					info_string = string.format("%s%s %s", info_string, msg_sender, msg_name)
					if consoleLogOn then
						info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, info_string: %s", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len, info_string))
					end
					local subtree_name_str = string.format("%s %s", subtree_name, msg_name)
					subtree = tree:add(p, buffer(), subtree_name_str)
					if msg_name == "SessionSetup" then 
						msg_byte_count = client_handle_session_setup(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "SetEncodings" then 
						msg_byte_count = client_handle_set_encodings(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "FramebufferUpdateRequest" then 
						msg_byte_count = client_handle_framebuffer_update_request(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "StreamSetupResponse" then 
						msg_byte_count = client_handle_stream_setup_response(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "StreamConfirm" then 
						msg_byte_count = client_handle_stream_confirm(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "SessionTerminateIndication" then 
						msg_byte_count = client_handle_session_terminate_indication(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "KeyEvent" then 
						msg_byte_count = client_handle_key_event(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "PointerEvent" then 
						msg_byte_count = client_handle_pointer_event(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmInitiateSessionResponse" then
						msg_byte_count = client_handle_cdm_initiate_session_response(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmAddLicenseResponse" then
						msg_byte_count = client_handle_cdm_add_license_response(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmAddLicenseIndication" then
						msg_byte_count = client_handle_cdm_add_license_indication(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmActionUpdate" then
						msg_byte_count = client_handle_cdm_action_update(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmStopSessionIndication" then
						msg_byte_count = client_handle_cdm_stop_session_indication(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					else
						subtree:add(buffer(0, 1),"RFBTV client message: " .. msg_name)
						subtree:add(buffer(1), "Data: " .. buffer(1))
						buffer = nil 
					end
				else
					msg_name = server_message_type[msg_key] or "unknown"
					info_string = string.format("%s%s %s", info_string, msg_sender, msg_name)
					if consoleLogOn then
						info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d, info_string: %s", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len, info_string))
					end
					local subtree_name_str = string.format("%s %s", subtree_name, msg_name)
					subtree = tree:add(p, buffer(), subtree_name_str)
					if msg_name == "SessionSetupResponse" then 
						msg_byte_count = server_handle_session_response_setup(buffer, pinfo, subtree) 
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "FramebufferUpdate" then 
						msg_byte_count = server_handle_framebuffer_update(buffer, pinfo, subtree) 
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
						if buffer ~= nil then
							if consoleLogOn then
								info(string.format("%s - Pkt: %d, bufLen: %d, desegment_offset: %d, desegment_len: %d", debug.getinfo(1, "l").currentline, pinfo.number, buffer:len(), pinfo.desegment_offset, pinfo.desegment_len))
							end
						else
							if consoleLogOn then
								info(string.format("%s - Pkt: %d, desegment_offset: %d, desegment_len: %d, buffer is nil", debug.getinfo(1, "l").currentline, pinfo.number, pinfo.desegment_offset, pinfo.desegment_len))
							end
						end
					elseif msg_name == "StreamSetup" then 
						msg_byte_count = server_handle_stream_setup(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "SessionTerminateRequest" then 
						msg_byte_count = server_handle_session_terminate_request(buffer, pinfo, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "PassThrough" then
						msg_byte_count = server_handle_passthrough_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "ServerCommand" then
						msg_byte_count = server_handle_server_command_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "HandoffRequest" then
						msg_byte_count = server_handle_handoff_request_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmInitiateSessionRequest" then
						msg_byte_count = server_handle_cdm_initiate_session_request_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmAddLicenseRequest" then
						msg_byte_count = server_handle_cdm_addlicense_request_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmActionRequest" then
						msg_byte_count = server_handle_cdm_action_request_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmStopSessionRequest" then
						msg_byte_count = server_handle_cdm_stop_session_request_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					elseif msg_name == "CdmStopSessionConfirm" then
						msg_byte_count = server_handle_cdm_stop_session_confirm_message(buffer, subtree)
						buffer = update_buffer(pinfo, buffer, msg_byte_count)
					else
						subtree:add(buffer(0, 1),"RFBTV server message: " .. msg_name)
						subtree:add(buffer(1), "Data: " .. buffer(1))
						buffer = nil 
					end
				end
			end 
		end
		pinfo.cols.info = string.format("%s", info_string)
	end

	tcp_table = DissectorTable.get("tcp.port")
	for _,port in pairs(server_ports) do
		tcp_table:add(port, p)
	end

end

