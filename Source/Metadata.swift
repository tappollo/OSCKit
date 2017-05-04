//
//  Metadata.swift
//  Pods
//
//  Created by BOON CHEW on 5/2/17.
//
//

import Foundation
import PromiseKit

public struct PhotoSphereMetadata {
    private let elements: [PhotoSphereTag: Any]

    init(elements: [PhotoSphereTag: Any]) {
        self.elements = elements
    }

    func isEquirectangular() -> Bool {
        if let projectionType = self.elements[.projectionType] {
            return (projectionType as String) == "equirectangular"
        }
    }

    func is360() -> Bool {
        return isEquirectangular()
    }
}

public enum PhotoSphereTag: String {
    case captureSoftware = "GPano:CaptureSoftware"
    case croppedAreaImageWidthPixels = "GPano:CroppedAreaImageWidthPixels"
    case croppedAreaImageHeightPixels = "GPano:CroppedAreaImageHeightPixels"
    case croppedAreaLeftPixels = "GPano:CroppedAreaLeftPixels"
    case croppedAreaTopPixels = "GPano:CroppedAreaTopPixels"
    case exposureLockUsed = "GPano:ExposureLockUsed"
    case firstPhotoDate = "GPano:FirstPhotoDate"
    case fullPanoWidthPixels = "GPano:FullPanoWidthPixels"
    case fullPanoHeightPixels = "GPano:FullPanoHeightPixels"
    case initialCameraDolly = "GPano:InitialCameraDolly"
    case initialHorizontalFOVDegrees = "GPano:InitialHorizontalFOVDegrees"
    case initialViewHeadingDegrees = "GPano:InitialViewHeadingDegrees"
    case initialViewPitchDegrees = "GPano:InitialViewPitchDegrees"
    case initialViewRollDegrees = "GPano:InitialViewRollDegrees"
    case lastPhotoDate = "GPano:LastPhotoDate"
    case poseHeadingDegrees = "GPano:PoseHeadingDegrees"
    case posePitchDegrees = "GPano:PosePitchDegrees"
    case poseRollDegrees = "GPano:PoseRollDegrees"
    case projectionType = "GPano:ProjectionType"
    case sourcePhotosCount = "GPano:SourcePhotosCount"
    case stitchingSoftware = "GPano:StitchingSoftware"
    case usePanoramaViewer = "GPano:UsePanoramaViewer"
}

class PhotoSphereMetadataParser: NSObject {
    private var metadata: Data
    private var parser: XMLParser?
    private static let xmpMetaStart = "<x:xmpmeta".data(using: .ascii)!
    private static let xmpMetaEnd   = "</x:xmpmeta>".data(using: .ascii)!

    fileprivate var elements: [PhotoSphereTag: Any]?
    fileprivate var element: PhotoSphereTag?
    fileprivate var elementHandler: ((String) -> Void)?

    fileprivate var fulfill: (([PhotoSphereTag: Any]) -> Void)!
    fileprivate var reject: ((Error) -> Void)!

    override init() {
        metadata = Data()
        super.init()
    }

    func parse(contentsOf url: URL) -> Promise<[PhotoSphereTag: Any]> {
        let data = try? Data(contentsOf: url)
        return self.parse(data: data)
    }

    func parse(data: Data?) -> Promise<[PhotoSphereTag: Any]> {
        guard let data = data else {
            return Promise { fulfill, reject in
                reject(OSCKit.SDKError.unableToParseMetadata)
            }
        }

        let (promise, fulfill, reject) = Promise<[PhotoSphereTag: Any]>.pending()

        self.fulfill = fulfill
        self.reject = reject

        if let startRange = data.range(of: PhotoSphereMetadataParser.xmpMetaStart), let endRange = data.range(of: PhotoSphereMetadataParser.xmpMetaEnd, in: Range(uncheckedBounds: (startRange.upperBound, data.count))) {
            let range = Range(uncheckedBounds: (startRange.lowerBound, endRange.upperBound))
            metadata = data.subdata(in: range)
        }

        parser = XMLParser(data: metadata)
        parser?.delegate = self

        return promise
    }
}

extension PhotoSphereMetadataParser: XMLParserDelegate {
    func parserDidStartDocument(_ parser: XMLParser) {
        (elements, element, elementHandler) = ([:], nil, nil)
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        self.fulfill(elements!)
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.reject(OSCKit.SDKError.unableToParseMetadata)
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {

        element = PhotoSphereTag(rawValue: elementName)
        if let element = element {
            switch element {
            // Boolean
            case .usePanoramaViewer: fallthrough
            case .exposureLockUsed:
                elementHandler = { self.elements?[element] = ($0 == "True") }

            // String
            case .captureSoftware: fallthrough
            case .stitchingSoftware: fallthrough
            case .projectionType:
                elementHandler = { self.elements?[element] = $0 }

            // Real
            case .poseHeadingDegrees: fallthrough
            case .posePitchDegrees: fallthrough
            case .poseRollDegrees: fallthrough
            case .initialHorizontalFOVDegrees: fallthrough
            case .initialCameraDolly:
                elementHandler = { self.elements?[element] = Double($0) ?? 0.0 }

            // Integer
            case .initialViewHeadingDegrees: fallthrough
            case .initialViewPitchDegrees: fallthrough
            case .initialViewRollDegrees: fallthrough
            case .sourcePhotosCount:fallthrough
            case .croppedAreaImageWidthPixels:fallthrough
            case .croppedAreaImageHeightPixels: fallthrough
            case .fullPanoWidthPixels: fallthrough
            case .fullPanoHeightPixels: fallthrough
            case .croppedAreaLeftPixels: fallthrough
            case .croppedAreaTopPixels:
                elementHandler = { self.elements?[element] = Int($0) ?? 0 }

            // Date
            case .firstPhotoDate: fallthrough
            case .lastPhotoDate:
                elementHandler = { string in
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                    let date = formatter.date(from: string)
                    self.elements?[element] = date ?? string
                }
            }
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if let handler = elementHandler {
            handler(string)

            element = nil
            elementHandler = nil
        }
    }
}

extension OSCKit {
    public func metadata(of url: URL) -> Promise<[PhotoSphereTag: Any]> {
        return PhotoSphereMetadataParser().parse(contentsOf: url)
    }

    public func metadata(of image: UIImage) -> Promise<[PhotoSphereTag: Any]> {
        let data = UIImageJPEGRepresentation(image, 1.0)
        return metadata(of: data!)
    }

    public func metadata(of data: Data) -> Promise<[PhotoSphereTag: Any]> {
        return PhotoSphereMetadataParser().parse(data: data)
    }
}

//OSCKit.shared.metadata(of: "").then { metadata in
//    if metadata.isPanorama {
//
//    }
//}
