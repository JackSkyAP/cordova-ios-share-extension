//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Warren Kim on 1/16/16.
//
//

import UIKit
import Social
import MobileCoreServices

@available(iOSApplicationExtension 8.0, *)
class ShareViewController: SLComposeServiceViewController {

    let suiteName = "group.com.your.group.id"
    let contentTypeList = kUTTypePropertyList as String
    let contentTypeImage = kUTTypeImage as String
    let contentTypeTitle = "public.plain-text"
    let contentTypeUrl = "public.url"
    let contentTypePhoto = "public.jpeg"
    
    override func didSelectPost() {
        self.getShareData()
    }
    private func getShareData() {
        self.loadJsExtensionValues { dict in
            // Send share data as url params to app view custom url
            let url = "inshikos://shareLink?" + self.dictionaryToQueryString(dict)
            self.doOpenUrl(url)
            self.extensionContext!.completeRequestReturningItems([], completionHandler: nil)
        }
    }
    private func dictionaryToQueryString(dict: Dictionary<String,String>) -> String {
        return dict.map({ entry in
            let value = entry.1
            let valueEncoded = value.stringByAddingPercentEncodingWithAllowedCharacters(.URLHostAllowedCharacterSet())
            return entry.0 + "=" + valueEncoded!
        }).joinWithSeparator("&")
    }
    private func loadJsExtensionValues(f: Dictionary<String,String> -> Void) {
        let content = extensionContext!.inputItems[0] as! NSExtensionItem
        if (self.hasAttachmentOfType(content, contentType: contentTypeList)) {
            self.loadJsDictionary(content) { dict in
                f(dict)
            }
        }
        else {
            self.loadUTIDictionary(content) { dict in
		// launch once all items have been processed
                if let contentCount = content.userInfo!["NSExtensionItemAttachmentsKey"]!.count{
                    if (dict.count==contentCount) {
                        f(dict)
                    }
                }
            }
        }
    }
    private func hasAttachmentOfType(content: NSExtensionItem,contentType: String) -> Bool {
        // Verify the provider is valid
        if let contents = content.attachments as? [NSItemProvider] {
            for attachment in contents {
                if attachment.hasItemConformingToTypeIdentifier(contentType) {
                    return true;
                }
                // handle images
                else if attachment.hasItemConformingToTypeIdentifier(contentTypeImage) {
                    return true;
                }
            }
        }
        return false;
    }
    private func loadJsDictionary(content: NSExtensionItem, f: Dictionary<String,String> -> Void)  {
        for attachment in content.attachments as! [NSItemProvider] {
            if attachment.hasItemConformingToTypeIdentifier(contentTypeImage) {
                attachment.loadItemForTypeIdentifier(contentTypeImage, options: nil) { data, error in
                    let tempName = "image.jpg"
                    let sharedFilePath: NSURL? = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier(self.suiteName)!.URLByAppendingPathComponent(tempName)
                    // hande image as url
                    if let url = data as? NSURL?{
                        if let imageData = NSData(contentsOfURL: url!) {
                            let getImage =  UIImage(data: imageData)
                            UIImageJPEGRepresentation(getImage!, 1.0)!.writeToFile(sharedFilePath!.path!, atomically: true)
                            let values = ["photo": sharedFilePath!.absoluteString, "userTitle": ""+self.contentText]
                            f(values)
                        }
                    }
                    // handle image as data
                    else if let getImage = data as? UIImage{
                        UIImageJPEGRepresentation(getImage, 1.0)!.writeToFile(sharedFilePath!.path!, atomically: true)
                        let values = ["photo": sharedFilePath!.absoluteString, "userTitle": ""+self.contentText]
                        f(values)
                    }
                }
            }
            else if attachment.hasItemConformingToTypeIdentifier(contentTypeList) {
                attachment.loadItemForTypeIdentifier(contentTypeList, options: nil) { data, error in
                    if ( error == nil && data != nil ) {
                        let jsDict = data as! NSDictionary
                        if let jsPreprocessingResults = jsDict[NSExtensionJavaScriptPreprocessingResultsKey] {
                            let values = jsPreprocessingResults as! Dictionary<String,String>
                            f(values)
                        }
                    }
                }
            }
        }
    }
    private func loadUTIDictionary(content: NSExtensionItem,f: Dictionary<String,String> -> Void) {
        var dict = Dictionary<String, String>()
        loadUTIString(content, utiKey: contentTypeUrl   , handler: { url_NSSecureCoding in
            let url_NSurl = url_NSSecureCoding as! NSURL
            let url_String = url_NSurl.absoluteString as String
            dict["url"] = url_String
            f(dict)
        })
        loadUTIString(content, utiKey: contentTypeTitle, handler: { title_NSSecureCoding in
            let title = title_NSSecureCoding as! String
            dict["title"] = title
            f(dict)
        })
    }
    private func loadUTIString(content: NSExtensionItem,utiKey: String,handler: NSSecureCoding -> Void) {
        for attachment in content.attachments as! [NSItemProvider] {
            if attachment.hasItemConformingToTypeIdentifier(utiKey) {
                attachment.loadItemForTypeIdentifier(utiKey, options: nil, completionHandler: { (data, error) -> Void in
                    if ( error == nil && data != nil ) {
                        handler(data!)
                    }
                })
            }
        }
    }

    // See http://stackoverflow.com/a/28037297/82609
    // Works fine for iOS 8.x and 9.0 but may not work anymore in the future :(
    private func doOpenUrl(url: String) {
        let urlNS = NSURL(string: url)!
        var responder = self as UIResponder?
        while (responder != nil){
            if responder!.respondsToSelector(Selector("openURL:")) == true{
                responder!.callSelector(Selector("openURL:"), object: urlNS, delay: 0)
            }
            responder = responder!.nextResponder()
        }
    }
}
// See http://stackoverflow.com/a/28037297/82609
extension NSObject {
    func callSelector(selector: Selector, object: AnyObject?, delay: NSTimeInterval) {
        let delay = delay * Double(NSEC_PER_SEC)
        let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay))
        dispatch_after(time, dispatch_get_main_queue(), {
            NSThread.detachNewThreadSelector(selector, toTarget:self, withObject: object)
        })
    }
}
