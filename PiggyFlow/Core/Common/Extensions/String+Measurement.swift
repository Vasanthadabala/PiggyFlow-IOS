import Foundation
import UIKit

extension String {
    /// Height this string needs when wrapped to `width` with the given attributes.
    /// Used by the PDF export to advance the cursor past multi-line text.
    func height(withConstrainedWidth width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = (self as NSString).boundingRect(
            with: constraintRect,
            options: .usesLineFragmentOrigin,
            attributes: attributes,
            context: nil
        )
        return ceil(boundingBox.height)
    }
}
