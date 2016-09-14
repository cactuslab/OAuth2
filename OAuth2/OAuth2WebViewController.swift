//
//  OAuth2WebViewController.swift
//  OAuth2
//
//  Created by Pascal Pfiffner on 7/15/14.
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

import UIKit


extension OAuth2
{
    /**
    Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads
    the authorize URL.
    
    Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
    web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
    call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
    view controller instance.
    
    :raises: Will raise if the authorize URL cannot be constructed from the settings used during initialization.
    
    :param: controller The view controller to use for presentation
    :param: params     Optional additional URL parameters
    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
    */
    public func authorizeEmbeddedFrom(controller: UIViewController, params: [String: String]?) -> OAuth2WebViewController {
        let url = authorizeURLWithRedirect(nil, scope: nil, params: params)
        return presentAuthorizeViewFor(url, intercept: redirect!, from: controller)
    }
    
    /**
    Presents a web view controller, contained in a UINavigationController, on the supplied view controller and loads
    the authorize URL.
    
    Automatically intercepts the redirect URL and performs the token exchange. It does NOT however dismiss the
    web view controller automatically, you probably want to do this in the `afterAuthorizeOrFailure` closure. Simply
    call this method first, then assign that closure in which you call `dismissViewController()` on the returned web
    view controller instance.
    
    :param: controller The view controller to use for presentation
    :param: redirect   The redirect URL to use
    :param: scope      The scope to use
    :param: params     Optional additional URL parameters
    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
    */
    public func authorizeEmbeddedFrom(controller: UIViewController,
        redirect: String,
        scope: String,
        params: [String: String]?) -> OAuth2WebViewController {
            let url = authorizeURLWithRedirect(redirect, scope: scope, params: params)
            return presentAuthorizeViewFor(url, intercept: redirect, from: controller)
    }
    
    /**
    Presents and returns a web view controller loading the given URL and intercepting the given URL.
    
    :returns: OAuth2WebViewController, embedded in a UINavigationController being presented automatically
    */
    func presentAuthorizeViewFor(url: NSURL, intercept: String, from: UIViewController) -> OAuth2WebViewController {
        let web = OAuth2WebViewController()
        web.title = viewTitle
        web.startURL = url
        
        let delegate = OAuth2WebViewDelegate()
        delegate.interceptURLString = intercept
        delegate.onIntercept = { url in
            self.handleRedirectURL(url)
            return true
        }
        delegate.onWillDismiss = { didCancel in
            if didCancel {
                self.didFail(nil)
            }
        }
        
        web.delegate = delegate
        
        let navi = UINavigationController(rootViewController: web)
        from.presentViewController(navi, animated: true, completion: nil)
        
        return web
    }
    
    
    public func webViewDelegateForAuthorization(params:[String: String]?) -> (UIWebViewDelegate, NSURL) {
        let url = authorizeURLWithRedirect(nil, scope: nil, params: params)
        
        let delegate = OAuth2WebViewDelegate()
        delegate.interceptURLString = redirect!
        delegate.onIntercept = { url in
            self.handleRedirectURL(url)
            return true
        }
        delegate.onWillDismiss = { didCancel in
            if didCancel {
                self.didFail(nil)
            }
        }
        
        return (delegate, url)
    }
}

class OAuth2WebViewDelegate: NSObject, UIWebViewDelegate {
    
    /** The URL string to intercept and respond to. */
    var interceptURLString: String? {
        didSet(oldURL) {
            if nil != interceptURLString {
                if let url = NSURL(string: interceptURLString!) {
                    interceptComponents = NSURLComponents(URL: url, resolvingAgainstBaseURL: true)
                }
                else {
                    print("Failed to parse URL \(interceptURLString), discarding")
                    interceptURLString = nil
                }
            }
            else {
                interceptComponents = nil
            }
        }
    }
    var interceptComponents: NSURLComponents?
    
    /** Closure called when the web view gets asked to load the redirect URL, specified in `interceptURLString`. */
    var onIntercept: ((url: NSURL) -> Bool)?
    
    /** Called when the web view is about to be dismissed. */
    var onWillDismiss: ((didCancel: Bool) -> Void)?
    
    // MARK: - Web View Delegate
    
    func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        // we compare the scheme and host first, then check the path (if there is any). Not sure if a simple string comparison
        // would work as there may be URL parameters attached
        if nil != onIntercept && request.URL?.scheme == interceptComponents?.scheme && request.URL?.host == interceptComponents?.host {
            let haveComponents = NSURLComponents(URL: request.URL!, resolvingAgainstBaseURL: true)
            if haveComponents?.path == interceptComponents?.path {
                return !onIntercept!(url: request.URL!)
            }
        }
        
        return true
    }
    
    func webView(webView: UIWebView, didFailLoadWithError error: NSError) {
        if NSURLErrorDomain == error.domain && NSURLErrorCancelled == error.code {
            return
        }
    }
    
}

/**
*  A simple iOS web view controller that allows you to display the login/authorization screen.
*/
public class OAuth2WebViewController: UIViewController
{
    
    var delegate:OAuth2WebViewDelegate?
    
    /** The URL to load on first show. */
    public var startURL: NSURL? {
        didSet(oldURL) {
            if nil != startURL && nil == oldURL && isViewLoaded() {
                loadURL(startURL!)
            }
        }
    }
    
    
    var cancelButton: UIBarButtonItem?
    var webView: UIWebView!
    var loadingView: UIView?
    
    init() {
        super.init(nibName: nil, bundle: nil)
    }
    
    required public init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    
    // MARK: - View Handling
    
    override public func loadView() {
        edgesForExtendedLayout = .All
        extendedLayoutIncludesOpaqueBars = true
        automaticallyAdjustsScrollViewInsets = true
        
        super.loadView()
        view.backgroundColor = UIColor.whiteColor()
        
        cancelButton = UIBarButtonItem(barButtonSystemItem: .Cancel, target: self, action: #selector(OAuth2WebViewController.cancel(_:)))
        navigationItem.rightBarButtonItem = cancelButton
        
        // create a web view
        webView = UIWebView()
//        webView.setTranslatesAutoresizingMaskIntoConstraints(false)
        webView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal
        webView.delegate = delegate
        
        view.addSubview(webView!)
        let views:[String : AnyObject] = ["web": webView!]
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[web]|", options: [], metrics: nil, views: views))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[web]|", options: [], metrics: nil, views: views))
    }
    
    override public func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if !webView.canGoBack {
            if nil != startURL {
                loadURL(startURL!)
            }
            else {
                webView.loadHTMLString("There is no `startURL`", baseURL: nil)
            }
        }
    }
    
    func showLoadingIndicator() {
        // TODO: implement
    }
    
    func hideLoadingIndicator() {
        // TODO: implement
    }
    
    func showErrorMessage(message: String, animated: Bool) {
        print("Error: \(message)")
    }
    
    
    // MARK: - Actions
    
    public func loadURL(url: NSURL) {
        webView.loadRequest(NSURLRequest(URL: url))
    }
    
    func goBack(sender: AnyObject?) {
        webView.goBack()
    }
    
    func cancel(sender: AnyObject?) {
        dismiss(true, animated: nil != sender ? true : false)
    }
    
    func dismiss(animated: Bool) {
        dismiss(false, animated: animated)
    }
    
    func dismiss(asCancel: Bool, animated: Bool) {
        webView.stopLoading()
        
        delegate?.onWillDismiss?(didCancel: asCancel)
        presentingViewController?.dismissViewControllerAnimated(animated, completion: nil)
    }
    
    
}

