component output="false" {

	/**
	* Init
	* @settings.inject coldbox:setting:cloudinary
	*/
	public Cloudinary function init(required settings){
		variables.api = {
			 key 		:settings.key
			,url     	:settings.url
			,cloudname	:settings.cloudname
			,secret  	:settings.secret
			,localroot  :settings.localroot?:""
		};
		
		return this;
	}

	public struct function upload(){
		// for possible args: http://cloudinary.com/documentation/upload_images#remote_upload
		var params = {"faces":true}
		for (arg in arguments){
			params[arg] = arguments[arg];
		}

		return call("image/upload", params, "post");
	}

	public string function getImageSrc(string transformations, boolean direct=false, boolean https=true){
		var result = "#variables.api.localroot#/"
		
		if (arguments.direct || result == "/") 
			result = "http#arguments.https?'s':''#://res.cloudinary.com/#variables.api.cloudname#/image/upload/"
		

		if (!isnull(arguments.transformations)){
			result &= "#arguments.transformations#/"
		}

		return result;
	}

	public struct function getDetails(required string public_id, string resource_type="image", string type="upload", boolean faces=false){
		var params = { "faces":arguments.faces }

		return callAdmin("resources/#arguments.resource_type#/#arguments.type#/#arguments.public_id#",params);
	}

	public struct function delete(string resource_type, string type, boolean all=false, string public_ids, string prefix, boolean keep_original=false){
		var params = duplicate(arguments)
		structdelete(params,"resource_type")
		structdelete(params,"type")

		return callAdmin("resources/#arguments.resource_type#/#arguments.type#",params,"delete");
	}

	private struct function paramsWithSignature(required struct params) {
		// these are the fields we need to include in signature if they appear in params
		// they say only these: ["callback", "eager", "format", "public_id", "tags", "timestamp", "transformation", "type"]
		// but i have found otherwise because they are fucknuts. fuck them.
		var signaturefields = ["callback", "eager", "format", "public_id", "tags", "timestamp", "transformation", "type", "folder", "invalidate", "faces"]

		// add timestamp
		arguments.params["timestamp"] = DateDiff("s", createdate(1970,1,1), now())

		// create array of params matching signaturefields
		var sigparams = []
		arguments.params.each(function(key, item){
			if (signaturefields.find(key))
				sigparams.append("#key#=#item#")
		})

		sigparams.sort("text");

		local.signatureraw = sigparams.toList("&");

		var MessageDigest = createobject("java","java.security.MessageDigest");
		var md = MessageDigest.getInstance("SHA-1");
		var digest = md.digest( (local.signatureraw & api.secret).getBytes() )
		var signature = binaryEncode(digest,"hex");

		arguments.params["signature"] = signature

		return arguments.params;
	}

	private function call(required string action, struct params, string method="get"){
		params["api_key"] = api.key;
		var parameters = paramsWithSignature(params);

		http url="#api.url#/#api.cloudname#/#arguments.action#" result="local.cfhttp" method="#arguments.method#" {
			for (local.param in parameters) {
				local.type = "url";
				if (arguments.method=="post")
					local.type = "formfield"

				if (isImageFile(parameters[local.param]))
					httpparam name="#local.param#" file="#parameters[local.param]#" type="file";
				else 
					httpparam name="#local.param#" value="#parameters[local.param]#" type="#local.type#";
			}
		}

		try {
			var result = deserializeJSON(local.cfhttp.filecontent)
			if (!isnull(result.error))
				throw;
		} catch (any local.e){
			throwAPIException(local.cfhttp.filecontent)
		}
		return result;
	}

	private function callAdmin(required string action, struct params={}, string method="get"){
		var parameters = arguments.params
		http url="#api.url#/#api.cloudname#/#arguments.action#" result="local.cfhttp" method="#arguments.method#" username="#api.key#" password="#api.secret#" {
			for (local.param in parameters) {
				local.type = "url";
				if (arguments.method=="post")
					local.type = "formfield"

				if (isImageFile(parameters[local.param]))
					httpparam name="#local.param#" file="#parameters[local.param]#" type="file";
				else 
					httpparam name="#local.param#" value="#parameters[local.param]#" type="#local.type#";
			}
		}

		try {
			var result = deserializeJSON(local.cfhttp.filecontent)
			if (!isnull(result.error))
				throw;
		} catch (any local.e){
			throwAPIException(local.cfhttp.filecontent)
		}
		return result;
	}


	private void function throwAPIException(required any response){

		throw(type:"CloudinaryException",message:"Cloudinary API Exception.",detail:serializeJSON(arguments.response));
	}

}