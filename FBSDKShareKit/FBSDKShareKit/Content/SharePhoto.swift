/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the license found in the
 * LICENSE file in the root directory of this source tree.
 */

import FBSDKCoreKit
import Foundation
import Photos
import UIKit

/// A photo for sharing.
@objcMembers
@objc(FBSDKSharePhoto)
public final class SharePhoto: NSObject, ShareMedia {

  // This property maintains a single source for the video: raw data, an asset or a URL
  private var source: Source?

  /// If the photo is resident in memory, this method supplies the data.
  public var image: UIImage? {
    get { source?.image }
    set { source = Source(newValue) }
  }

  /// URL that points to a network location or the location of the photo on disk
  public var imageURL: URL? {
    get { source?.url }
    set { source = Source(newValue) }
  }

  /// The representation of the photo in the Photos library.
  public var photoAsset: PHAsset? {
    get { source?.asset }
    set { source = Source(newValue) }
  }

  /// Specifies whether the photo represented by the receiver was generated by the user (`true`)
  /// or by the application (`false`).
  public var isUserGenerated: Bool

  /**
   The user-generated caption for the photo. Note that the 'caption' must come from
   the user, as pre-filled content is forbidden by the Platform Policies (2.3).
   */
  public var caption: String?

  /**
   Convenience method to build a new photo object with an image.
   - Parameter image If the photo is resident in memory, this method supplies the data
   - Parameter isUserGenerated Specifies whether the photo represented by the receiver was generated by the user or by the
   application
   */
  public convenience init(image: UIImage, isUserGenerated: Bool) {
    self.init(source: .image(image), isUserGenerated: isUserGenerated)
  }

  /**
   Convenience method to build a new photo object with an imageURL.
   - Parameter imageURL The URL to the photo
   - Parameter isUserGenerated Specifies whether the photo represented by the receiver was generated by the user or by the
   application

   This method should only be used when adding photo content to open graph stories.
   For example, if you're trying to share a photo from the web by itself, download the image and use
   `init(image:isUserGenerated:)` instead.
   */
  public convenience init(imageURL: URL, isUserGenerated: Bool) {
    self.init(source: .url(imageURL), isUserGenerated: isUserGenerated)
  }

  /**
   Convenience method to build a new photo object with a PHAsset.
   - Parameter photoAsset: The PHAsset that represents the photo in the Photos library.
   - Parameter isUserGenerated: Specifies whether the photo represented by the receiver was generated by the user or by
   the application
   */
  public convenience init(photoAsset: PHAsset, isUserGenerated: Bool) {
    self.init(source: .asset(photoAsset), isUserGenerated: isUserGenerated)
  }

  init(
    source: Source? = nil,
    isUserGenerated: Bool = false
  ) {
    self.source = source
    self.isUserGenerated = isUserGenerated
  }
}

extension SharePhoto: SharingValidation {
  /// Asks the receiver to validate that its content or media values are valid.
  @objc(validateWithOptions:error:)
  public func validate(options bridgeOptions: ShareBridgeOptions) throws {
    let errorFactory = ErrorFactory()

    guard bridgeOptions != .photoImageURL else {
      guard let url = source?.url else {
        throw errorFactory.invalidArgumentError(
          domain: ShareErrorDomain,
          name: "photo",
          value: self,
          message: "imageURL is required.",
          underlyingError: nil
        )
      }

      // a web-based URL is required
      guard !url.isFileURL else {
        throw errorFactory.invalidArgumentError(
          domain: ShareErrorDomain,
          name: "imageURL",
          value: url,
          message: "Cannot refer to a local file resource.",
          underlyingError: nil
        )
      }

      return
    }

    switch source {
    case let .asset(asset):
      guard asset.mediaType == .image else {
        throw errorFactory.invalidArgumentError(
          domain: ShareErrorDomain,
          name: "photoAsset",
          value: asset,
          message: "Must refer to a photo or other static image.",
          underlyingError: nil
        )
      }

      // Will bridge the PHAsset.localIdentifier or will load the asset and bridge the image
      return
    case let .url(url):
      guard url.isFileURL else {
        throw errorFactory.invalidArgumentError(
          domain: ShareErrorDomain,
          name: "imageURL",
          value: url,
          message: "Must refer to a local file resource.",
          underlyingError: nil
        )
      }

      // Will load the contents of the file and bridge the image
      return
    case .image:
      // Will bridge the image
      return
    case nil:
      throw errorFactory.invalidArgumentError(
        domain: ShareErrorDomain,
        name: "photo",
        value: self,
        message: "Must have an asset, image, or imageURL value.",
        underlyingError: nil
      )
    }
  }
}

extension SharePhoto {
  // This helps us make sure that only one type of source is used
  enum Source {
    case image(UIImage)
    case url(URL)
    case asset(PHAsset)

    var image: UIImage? {
      switch self {
      case let .image(image): return image
      default: return nil
      }
    }

    var url: URL? {
      switch self {
      case let .url(url): return url
      default: return nil
      }
    }

    var asset: PHAsset? {
      switch self {
      case let .asset(asset): return asset
      default: return nil
      }
    }

    init?(_ image: UIImage?) {
      guard let image = image else { return nil }

      self = .image(image)
    }

    init?(_ url: URL?) {
      guard let url = url else { return nil }

      self = .url(url)
    }

    init?(_ asset: PHAsset?) {
      guard let asset = asset else { return nil }

      self = .asset(asset)
    }
  }
}
