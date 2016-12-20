//
//  OAuth2CodeGrantFacebook.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 2/1/15.
//  Copyright 2015 Pascal Pfiffner
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
	Facebook only returns an "access_token=xyz&..." string, no true JSON, hence we override `parseTokenExchangeResponse`
	and deal with the situation in a subclass.
 */
open class OAuth2CodeGrantFacebook: OAuth2CodeGrant
{
	override func parseTokenExchangeResponse(_ data: Data, error: NSErrorPointer) -> OAuth2JSON? {
		if let str = NSString(data: data, encoding: String.Encoding.utf8.rawValue) as? String {
			let query = type(of: self).paramsFromQuery(str)
			if let access = query["access_token"] {
				accessToken = access
				return ["access_token": accessToken as AnyObject]
			}
		}
		return nil
	}
}

