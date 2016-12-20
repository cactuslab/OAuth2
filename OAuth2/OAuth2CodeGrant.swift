//
//  OAuth2CodeGrant.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 6/16/14.
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
 *  A class to handle authorization for confidential clients via the authorization code grant method.
 *
 *  This auth flow is designed for clients that are capable of protecting their client secret, which a distributed Mac/iOS App **is not**!
 */
open class OAuth2CodeGrant: OAuth2
{
	/** The URL string where we can exchange a code for a token; if nil `authURL` will be used. */
    open let tokenURL: URL?
	
	/** The receiver's long-time refresh token. */
	open var refreshToken = ""
	
	public override init(settings: OAuth2JSON) {
        if let token = settings["token_uri"] as? String {
            tokenURL = URL(string: token)
        }
        else {
            tokenURL = nil
        }
        
		super.init(settings: settings)
	}
	
	
	override open func authorizeURLWithRedirect(_ redirect: String?, scope: String?, params: [String: String]?) -> URL {
		return authorizeURL(authURL!, redirect: redirect, scope: scope, responseType: "code", params: params)
	}
	
    open func tokenURLWithRedirect(_ redirect: String?, code: String, params: [String: String]?) -> URL {
        let base = tokenURL ?? authURL! as URL
        var urlParams = params ?? [String: String]()
        urlParams["code"] = code
        urlParams["grant_type"] = "authorization_code"
        if nil != clientSecret {
            urlParams["client_secret"] = clientSecret!
        }
        
        return authorizeURL(base, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
    }
    
    /**
    Create a request for token exchange
    */
    open func tokenRequest(_ code: String) -> URLRequest {
        let url = tokenURLWithRedirect(redirect, code: code, params: nil)
        var comp = URLComponents(url: url, resolvingAgainstBaseURL: true)
        assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
        let body = comp!.query
        comp!.query = nil
        
        let post = NSMutableURLRequest(url: comp!.url!)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        post.setValue("application/json", forHTTPHeaderField: "Accept")
        post.httpBody = body?.data(using: String.Encoding.utf8, allowLossyConversion: true)
        
        return post as URLRequest
    }
    
    func refreshTokenURLWithRedirect(_ redirect: String?, code: String, params: [String: String]?) -> URL {
        let base = tokenURL ?? authURL! as URL
        var urlParams = params ?? [String: String]()
        urlParams["refresh_token"] = refreshToken
        urlParams["grant_type"] = "refresh_token"
        urlParams["client_id"] = clientId
        if let clientSecret = clientSecret {
            urlParams["client_secret"] = clientSecret
        }
        if let scope = scope {
            urlParams["scope"] = scope
        }
        
        return authorizeURL(base, redirect: redirect, scope: nil, responseType: nil, params: urlParams)
    }
    
    /**
    Create a request for token exchange
    */
    func refreshTokenRequest() -> URLRequest {
        let url = refreshTokenURLWithRedirect(redirect, code: refreshToken, params: nil)
        var comp = URLComponents(url: url, resolvingAgainstBaseURL: true)
        assert(comp != nil, "It seems NSURLComponents cannot parse \(url)");
        let body = comp!.query
        comp!.query = nil
        
        let post = NSMutableURLRequest(url: comp!.url!)
        post.httpMethod = "POST"
        post.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        post.setValue("application/json", forHTTPHeaderField: "Accept")
        post.httpBody = body?.data(using: String.Encoding.utf8, allowLossyConversion: true)
        
        return post as URLRequest
    }
    
    /**
        Refresh the access token if a refresh token is available.
     */
    open func refreshAuthorizationToken() {
        // do we have a code?
        if (refreshToken.isEmpty) {
            didFail(genOAuth2Error("I don't have a refresh code to exchange, let the user authorize first", code: .prerequisiteFailed))
            logIfVerbose("No code to exchange for a token, cannot continue")
            return;
        }
        
        let post = refreshTokenRequest()
        logIfVerbose("Exchanging code \(refreshToken) with redirect \(redirect!) for token at \(post.url?.description)")
        
        // perform the exchange
        let session = URLSession.shared
        let task = session.dataTask(with: post, completionHandler: { sessData, sessResponse, error in
            var finalError: NSError?
            
            if nil != error {
                finalError = error as NSError?
            }
            else if let data = sessData, let http = sessResponse as? HTTPURLResponse {
                if let json = self.parseTokenExchangeResponse(data, error: &finalError) {
                    if 200 == http.statusCode {
                        self.logIfVerbose("Did receive access token: \(self.accessToken), refresh token: \(self.refreshToken)")
                        self.didAuthorize(json)
                        return
                    }
                    
                    let desc = (json["error_description"] ?? json["error"]) as? String
                    finalError = genOAuth2Error(desc ?? http.statusString, code: .authorizationError)
                }
            }
            
            // if we're still here an error must have happened
            if nil == finalError {
                finalError = genOAuth2Error("Unknown connection error for response \(sessResponse) with data \(sessData)", code: .networkError)
            }
            
            self.didFail(finalError)
        }) 
        task.resume()

    }
    
    
	/**
		Extracts the code from the redirect URL and exchanges it for a token.
	 */
	override open func handleRedirectURL(_ redirect: URL) {
		logIfVerbose("Handling redirect URL \(redirect.description)")
		
		let (code, error) = validateRedirectURL(redirect)
		if nil != error {
			didFail(error)
		}
		else {
			exchangeCodeForToken(code!)
		}
	}
	
	/**
		Takes the received code and exchanges it for a token.
	 */
	func exchangeCodeForToken(_ code: String) {
		
		// do we have a code?
		if (code.isEmpty) {
			didFail(genOAuth2Error("I don't have a code to exchange, let the user authorize first", code: .prerequisiteFailed))
			logIfVerbose("No code to exchange for a token, cannot continue")
			return;
		}
		
		let post = tokenRequest(code)
		logIfVerbose("Exchanging code \(code) with redirect \(redirect!) for token at \(post.url?.description)")
		
		// perform the exchange
		let session = URLSession.shared
		let task = session.dataTask(with: post, completionHandler: { sessData, sessResponse, error in
			var finalError: NSError?
			
			if nil != error {
				finalError = error as NSError?
			}
			else if let data = sessData, let http = sessResponse as? HTTPURLResponse {
				if let json = self.parseTokenExchangeResponse(data, error: &finalError) {
					if 200 == http.statusCode {
						self.logIfVerbose("Did receive access token: \(self.accessToken), refresh token: \(self.refreshToken)")
						self.didAuthorize(json)
						return
					}
					
					let desc = (json["error_description"] ?? json["error"]) as? String
					finalError = genOAuth2Error(desc ?? http.statusString, code: .authorizationError)
				}
			}
			
			// if we're still here an error must have happened
			if nil == finalError {
				finalError = genOAuth2Error("Unknown connection error for response \(sessResponse) with data \(sessData)", code: .networkError)
			}
			
			self.didFail(finalError)
		}) 
		task.resume()
	}
	
	/**
		Parse the NSData object returned while exchanging the code for a token in `exchangeCodeForToken`.
	
		:returns: A OAuth2JSON, which is usually returned upon token exchange and may contain additional information
	 */
	func parseTokenExchangeResponse(_ data: Data, error: NSErrorPointer) -> OAuth2JSON? {
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves) as? OAuth2JSON {
                if let access = json["access_token"] as? String {
                    accessToken = access
                }
                accessTokenExpiry = nil
                if let expires = json["expires_in"] as? TimeInterval {
                    accessTokenExpiry = Date(timeIntervalSinceNow: expires)
                }
                if let refresh = json["refresh_token"] as? String {
                    refreshToken = refresh
                }
                
                return json
            }
        } catch {
            // Nothings
        }
		return nil
	}
	
	
	// MARK: - Utilities
	
	/**
		Validates the redirect URI: returns a tuple with the code and nil on success, nil and an error on failure.
	 */
	func validateRedirectURL(_ redirect: URL) -> (code: String?, error: NSError?) {
		var code: String?
		var error: NSError?
		
		let comp = URLComponents(url: redirect, resolvingAgainstBaseURL: true)
		if let compQuery = comp?.query, compQuery.characters.count > 0 {
			let query = OAuth2CodeGrant.paramsFromQuery(comp!.query!)
			if let cd = query["code"] {
				
				// we got a code, use it if state is correct (and reset state)
				if let st = query["state"], st == state {
					code = cd
					state = ""
				}
				else {
					error = genOAuth2Error("Invalid state, will not use the code", code: .invalidState)
				}
			}
			else {
				error = OAuth2CodeGrant.errorForAccessTokenErrorResponse(query as OAuth2JSON)
			}
		}
		else {
			error = genOAuth2Error("The redirect URL contains no query fragment", code: .prerequisiteFailed)
		}
		
		if nil != error {
			logIfVerbose("Invalid redirect URL: \(error!.localizedDescription)")
		}
		else {
			logIfVerbose("Successfully validated redirect URL")
		}
		return (code, error)
	}
}

