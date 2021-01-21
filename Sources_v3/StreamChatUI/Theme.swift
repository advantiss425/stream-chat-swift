//
// Copyright © 2021 Stream.io Inc. All rights reserved.
//

import UIKit

/// WIP: The title of this protocol says it all.
public protocol ColorTheme {
    // MARK: - Text

    /// General textColor, should be something that contrasts great with your
    var text: UIColor { get set }
    var text2: UIColor { get set }
    var subtitleText: UIColor { get set }

    // MARK: - Text interactions

    var highlightedColorForColor: (UIColor) -> UIColor { get set }
    var disabledColorForColor: (UIColor) -> UIColor { get set }
    var unselectedColorForColor: (UIColor) -> UIColor { get set }

    // MARK: - Background

    var generalBackground: UIColor { get set }
    var background: UIColor { get set }
    var background1: UIColor { get set }
    var background2: UIColor { get set }
    var background3: UIColor { get set }
    var background4: UIColor { get set }

    var popoverBackground: UIColor { get set }
    var highlightedBackground: UIColor { get set }
    var highlightedBackground2: UIColor { get set }

    // MARK: - Borders and shadows

    var shadow: UIColor { get set }
    var lightBorder: UIColor { get set }
    var border: UIColor { get set }
    var border2: UIColor { get set }

    // MARK: - Tint and alert

    var alert: UIColor { get set }
    var alternativeActiveTint: UIColor { get set }
    var inactiveTint: UIColor { get set }
}
