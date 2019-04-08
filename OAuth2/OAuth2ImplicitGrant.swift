//
//  OAuth2ImplicitGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/9/14.
//  Copyright 2014 Pascal Pfiffner
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation


/**
 *  Class to handle OAuth2 requests for public clients, such as distributed Mac/iOS Apps.
 */
open class OAuth2ImplicitGrant: OAuth2
{
	override open func authorizeURLWithRedirect(_ redirect: String?, scope: String?, params: [String: String]?) -> URL {
		return authorizeURL(authURL!, redirect: redirect, scope: scope, responseType: "token", params: params)
	}
	
	override open func handleRedirectURL(_ redirect: URL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		var error: NSError?
		let comp = URLComponents(url: redirect, resolvingAgainstBaseURL: true)
		
		// token should be in the URL fragment
		if let fragment = comp?.fragment, fragment.count > 0 {
			let params = OAuth2ImplicitGrant.paramsFromQuery(fragment)
			if let token = params["access_token"], token.count > 0 {
				if let tokType = params["token_type"] {
					if "bearer" == tokType.lowercased() {
						
						// got a "bearer" token, use it if state checks out
						if let tokState = params["state"] {
							if tokState == state {
								accessToken = token
								accessTokenExpiry = nil
                                if let expiresValue = params["expires_in"], let expires = Int(expiresValue) {
									accessTokenExpiry = Date(timeIntervalSinceNow: TimeInterval(expires))
								}
								logIfVerbose("Successfully extracted access token \(token)")
								didAuthorize(params as OAuth2JSON)
								return
							}
							
							error = genOAuth2Error("Invalid state \(tokState), will not use the token", code: .invalidState)
						}
						else {
							error = genOAuth2Error("No state returned, will not use the token", code: .invalidState)
						}
					}
					else {
						error = genOAuth2Error("Only \"bearer\" token is supported, but received \"\(tokType)\"", code: .unsupported)
					}
				}
				else {
					error = genOAuth2Error("No token type received, will not use the token", code: .prerequisiteFailed)
				}
			}
			else {
				error = OAuth2ImplicitGrant.errorForAccessTokenErrorResponse(params as OAuth2JSON)
			}
		}
		else {
			error = genOAuth2Error("Invalid redirect URL: \(redirect)", code: .prerequisiteFailed)
		}
		
		// log, if needed, then report back
		logIfVerbose("Error handling redirect URL: \(error!.localizedDescription)")
		didFail(error)
	}
}

