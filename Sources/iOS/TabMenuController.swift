/*
 * Copyright (C) 2015 - 2017, Daniel Dahan and CosmicMind, Inc. <http://cosmicmind.com>.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *	*	Redistributions of source code must retain the above copyright notice, this
 *		list of conditions and the following disclaimer.
 *
 *	*	Redistributions in binary form must reproduce the above copyright notice,
 *		this list of conditions and the following disclaimer in the documentation
 *		and/or other materials provided with the distribution.
 *
 *	*	Neither the name of CosmicMind nor the names of its
 *		contributors may be used to endorse or promote products derived from
 *		this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit

/// A memory reference to the TabMenuBarItem instance for UIViewController extensions.
fileprivate var TabMenuBarItemKey: UInt8 = 0

open class TabMenuBarItem: FlatButton {
    open override func prepare() {
        super.prepare()
        pulseAnimation = .none
    }
}

@objc(TabMenuAlignment)
public enum TabMenuAlignment: Int {
    case top
    case bottom
    case hidden
}

extension UIViewController {
    /// tabMenuBarItem reference.
    public private(set) var tabMenuBarItem: TabMenuBarItem {
        get {
            return AssociatedObject(base: self, key: &TabMenuBarItemKey) {
                return TabMenuBarItem()
            }
        }
        set(value) {
            AssociateObject(base: self, key: &TabMenuBarItemKey, value: value)
        }
    }
}

extension UIViewController {
    /**
     A convenience property that provides access to the TabMenuController.
     This is the recommended method of accessing the TabMenuController
     through child UIViewControllers.
     */
    public var tabMenuBarController: TabMenuController? {
        var viewController: UIViewController? = self
        while nil != viewController {
            if viewController is TabMenuController {
                return viewController as? TabMenuController
            }
            viewController = viewController?.parent
        }
        return nil
    }
}

open class TabMenuController: UIViewController {
    @IBInspectable
    open var selectedIndex: Int {
        didSet {
            scrollView.setContentOffset(CGPoint(x: scrollView.width * CGFloat(selectedIndex), y: 0), animated: true)
            
            guard false == tabBar?.isAnimating else {
                return
            }
            
            tabBar?.select(at: selectedIndex)
        }
    }
    
    /// Enables and disables bouncing when swiping.
    open var isBounceEnabled: Bool {
        get {
            return scrollView.bounces
        }
        set(value) {
            scrollView.bounces = value
        }
    }
    
    /// The TabBar used to switch between view controllers.
    @IBInspectable
    open fileprivate(set) var tabBar: TabBar?
    
    /// The UIScrollView used to pan the application pages.
    @IBInspectable
    open let scrollView = UIScrollView()
    
    /// An Array of UIViewControllers.
    open var viewControllers: [UIViewController] {
        didSet {
            oldValue.forEach {
                $0.willMove(toParentViewController: nil)
                $0.view.removeFromSuperview()
                $0.removeFromParentViewController()
            }
            
            prepareViewControllers()
            layoutSubviews()
        }
    }
    
    open var tabMenuAlignment = TabMenuAlignment.bottom {
        didSet {
            layoutSubviews()
        }
    }
    
    /**
     An initializer that initializes the object with a NSCoder object.
     - Parameter aDecoder: A NSCoder instance.
     */
    public required init?(coder aDecoder: NSCoder) {
        viewControllers = []
        selectedIndex = 0
        super.init(coder: aDecoder)
    }
    
    /**
     An initializer that accepts an Array of UIViewControllers.
     - Parameter viewControllers: An Array of UIViewControllers.
     */
    public init(viewControllers: [UIViewController], selectedIndex: Int = 0) {
        self.viewControllers = viewControllers
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        prepare()
    }
    
    open override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        layoutSubviews()
    }
    
    /**
     To execute in the order of the layout chain, override this
     method. `layoutSubviews` should be called immediately, unless you
     have a certain need.
     */
    open func layoutSubviews() {
        layoutScrollView()
        layoutViewControllers()
    
        let p = (tabBar?.intrinsicContentSize.height ?? 0) + (tabBar?.layoutEdgeInsets.top ?? 0) + (tabBar?.layoutEdgeInsets.bottom ?? 0)
        let y = view.height - p
        
        tabBar?.height = p
        tabBar?.width = view.width + (tabBar?.layoutEdgeInsets.left ?? 0) + (tabBar?.layoutEdgeInsets.right ?? 0)
        
        switch tabMenuAlignment {
        case .top:
            tabBar?.isHidden = false
            tabBar?.y = 0
            scrollView.y = p
            scrollView.height = y
        case .bottom:
            tabBar?.isHidden = false
            tabBar?.y = y
            scrollView.y = 0
            scrollView.height = y
        case .hidden:
            tabBar?.isHidden = true
            scrollView.y = 0
            scrollView.height = view.height
        }
    }
    
    /**
     Prepares the view instance when intialized. When subclassing,
     it is recommended to override the prepare method
     to initialize property values and other setup operations.
     The super.prepare method should always be called immediately
     when subclassing.
     */
    open func prepare() {
        prepareScrollView()
        prepareViewControllers()
    }
}

extension TabMenuController {
    /// Prepares the scrollView used to pan through view controllers.
    fileprivate func prepareScrollView() {
        scrollView.delegate = self
        scrollView.bounces = false
        scrollView.isPagingEnabled = true
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        view.addSubview(scrollView)
    }
    
    /// Prepares the view controllers.
    fileprivate func prepareViewControllers() {
        let count = 2 < viewControllers.count ? 3 : viewControllers.count
        scrollView.contentSize = CGSize(width: scrollView.width * CGFloat(count), height: scrollView.height)
        
        if 0 == selectedIndex {
            for i in 0..<count {
                let vc = viewControllers[i]
                addChildViewController(vc)
                vc.didMove(toParentViewController: self)
                vc.view.clipsToBounds = true
                vc.view.contentScaleFactor = Screen.scale
                scrollView.addSubview(vc.view)
            }
        } else if viewControllers.count - 1 == selectedIndex {
            for i in 0..<count {
                let vc = viewControllers[count - i - 1]
                addChildViewController(vc)
                vc.didMove(toParentViewController: self)
                vc.view.clipsToBounds = true
                vc.view.contentScaleFactor = Screen.scale
                scrollView.addSubview(vc.view)
            }
        } else {
            var vc = viewControllers[selectedIndex]
            addChildViewController(vc)
            vc.didMove(toParentViewController: self)
            vc.view.clipsToBounds = true
            vc.view.contentScaleFactor = Screen.scale
            scrollView.addSubview(vc.view)
            
            vc = viewControllers[selectedIndex - 1]
            addChildViewController(vc)
            vc.didMove(toParentViewController: self)
            vc.view.clipsToBounds = true
            vc.view.contentScaleFactor = Screen.scale
            scrollView.addSubview(vc.view)
            
            vc = viewControllers[selectedIndex + 1]
            addChildViewController(vc)
            vc.didMove(toParentViewController: self)
            vc.view.clipsToBounds = true
            vc.view.contentScaleFactor = Screen.scale
            scrollView.addSubview(vc.view)
        }
        
        prepareTabBar()
    }
    
    /**
     Prepares the tabBar buttons.
     - Parameter _ buttons: An Array of UIButtons.
     */
    fileprivate func prepareTabBarButtons(_ buttons: [UIButton]) {
        guard let tb = tabBar else {
            return
        }
        
        tb.buttons = buttons
        
        for v in tb.buttons {
            v.removeTarget(self, action: #selector(tb.handleButton(button:)), for: .touchUpInside)
            v.removeTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
            v.addTarget(self, action: #selector(handleTabBarButton(button:)), for: .touchUpInside)
        }
        
        tb.select(at: selectedIndex)
    }
    
    fileprivate func prepareTabBar() {
        guard 0 < viewControllers.count else {
            return
        }
        
        var buttons = [UIButton]()
        
        for v in viewControllers {
            let button = v.tabMenuBarItem as UIButton
            buttons.append(button)
        }
        
        guard 0 < buttons.count else {
            tabBar = nil
            return
        }
        
        guard nil == tabBar else {
            prepareTabBarButtons(buttons)
            return
        }
        
        tabBar = TabBar()
        tabBar?.isLineAnimated = false
        tabBar?.lineAlignment = .top
        view.addSubview(tabBar!)
        prepareTabBarButtons(buttons)
    }
}

extension TabMenuController {
    fileprivate func layoutScrollView() {
        scrollView.frame = view.bounds
        scrollView.contentSize = CGSize(width: scrollView.width * CGFloat(viewControllers.count), height: scrollView.height)
        scrollView.contentOffset = CGPoint(x: scrollView.width * CGFloat(selectedIndex), y: 0)
    }
    
    fileprivate func layoutViewControllers() {
        let count = 2 < viewControllers.count ? 3 : viewControllers.count
        scrollView.contentSize = CGSize(width: scrollView.width * CGFloat(count), height: scrollView.height)
        
        if 0 == selectedIndex {
            for i in 0..<count {
                let vc = viewControllers[i]
                vc.view.frame = CGRect(x: CGFloat(i) * scrollView.width, y: 0, width: scrollView.width, height: scrollView.height)
            }
        } else if viewControllers.count - 1 == selectedIndex {
            for i in 0..<count {
                let j = count - i - 1
                let vc = viewControllers[j]
                vc.view.frame = CGRect(x: CGFloat(j) * scrollView.width, y: 0, width: scrollView.width, height: scrollView.height)
            }
        } else {
            var vc = viewControllers[selectedIndex]
            vc.view.frame = CGRect(x: scrollView.width, y: 0, width: scrollView.width, height: scrollView.height)
            
            vc = viewControllers[selectedIndex - 1]
            vc.view.frame = CGRect(x: 0, y: 0, width: scrollView.width, height: scrollView.height)
            
            vc = viewControllers[selectedIndex + 1]
            vc.view.frame = CGRect(x: 2 * scrollView.width, y: 0, width: scrollView.width, height: scrollView.height)
        }

    }
}

extension TabMenuController {
    /**
     Handles the pageTabBarButton.
     - Parameter button: A UIButton.
     */
    @objc
    fileprivate func handleTabBarButton(button: UIButton) {
        guard let tb = tabBar else {
            return
        }
        
        guard let index = tb.buttons.index(of: button) else {
            return
        }
        
        guard index != selectedIndex else {
            return
        }
        
        if 1 < abs(index - selectedIndex) {
            let last = viewControllers.count - 1
            var pos = 0
            
            if last == selectedIndex {
                pos = last - 1
            } else if 0 == selectedIndex {
                pos = 1
            } else {
                pos = selectedIndex + (index > selectedIndex ? 1 : -1)
            }
            
            scrollView.setContentOffset(CGPoint(x: scrollView.width * CGFloat(pos), y: 0), animated: false)
        }
        
        selectedIndex = index
    }
}

extension TabMenuController: UIScrollViewDelegate {
    @objc
    open func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let tb = tabBar else {
            return
        }
        
        guard tb.isAnimating else {
            return
        }
        
        guard let selected = tb.selected else {
            return
        }
        
        let x = (scrollView.contentOffset.x - scrollView.width) / scrollView.contentSize.width * scrollView.width
        tb.line.center.x = selected.center.x + x
    }
    
    @objc
    open func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        selectedIndex = lround(Double(scrollView.contentOffset.x / scrollView.width))
    }
}