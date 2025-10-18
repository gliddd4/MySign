import SwiftUI
import CoreHaptics

struct ButtonStyleShowcase: View {
    @EnvironmentObject var themeAccent: Theme
    @Environment(\.presentationMode) var presentationMode
    @State private var isToggleOn = false
    @State private var textInput = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 12) {
                    
                    // MARK: - Button Styles
                    CenteredSectionHeader(title: "BUTTON STYLES")
                    
                    VStack(spacing: 12) {
                        // Main Button
                        MainButtonView("Woah!") {
                            ToastManager.shared.showToast.log("Tapped Main Button")
                        }
                        .padding(.horizontal)
                        
                        // Hold and Release Button (Linear Increase + Sharpness)
                        Button("Woah!") {
                            ToastManager.shared.showToast.log("Tapped Hold & Release")
                        }
                        .buttonStyle(HoldAndReleaseButtonStyle(
                            color: themeAccent.accentColor,
                            accentColor: themeAccent.accentColor
                        ))
                        .padding(.horizontal)
                    }
                    .padding(.top, -8)
                    
                    // MARK: - Split Button Styles
                    CenteredSectionHeader(title: "SPLIT BUTTONS")
                    
                    VStack(spacing: 12) {
                        // Split Button (2 buttons)
                        SplitMainButton(
                            left: (title: "Left", icon: "arrow.left", action: {
                                ToastManager.shared.showToast.log("Tapped Split Left Button")
                            }),
                            right: (title: "Right", icon: "arrow.right", action: {
                                ToastManager.shared.showToast.log("Tapped Split Right Button")
                            })
                        )
                        .padding(.horizontal)
                        
                        // Triple Split Button (3 buttons)
                        TripleSplitMainButton(
                            left: (title: "Left", icon: "arrow.left", action: {
                                ToastManager.shared.showToast.log("Tapped Triple Split Left Button")
                            }),
                            middle: (title: "Middle", icon: "arrow.up.arrow.down", action: {
                                ToastManager.shared.showToast.log("Tapped Triple Split Middle Button")
                            }),
                            right: (title: "Right", icon: "arrow.right", action: {
                                ToastManager.shared.showToast.log("Tapped Triple Split Right Button")
                            })
                        )
                        .padding(.horizontal)
                        
                        // Four Split Button (4 buttons)
                        FourSplitMainButton(
                            left: (title: "First", icon: "1.square", action: {
                                ToastManager.shared.showToast.log("Tapped Four Split First Button")
                            }),
                            middle1: (title: "Second", icon: "2.square", action: {
                                ToastManager.shared.showToast.log("Tapped Four Split Second Button")
                            }),
                            middle2: (title: "Third", icon: "3.square", action: {
                                ToastManager.shared.showToast.log("Tapped Four Split Third Button")
                            }),
                            right: (title: "Fourth", icon: "4.square", action: {
                                ToastManager.shared.showToast.log("Tapped Four Split Fourth Button")
                            })
                        )
                        .padding(.horizontal)
                    }
                    .padding(.top, -8)
                    
                    // MARK: - Basic Labels
                    CenteredSectionHeader(title: "BASIC LABELS")
                    
                    ConnectedLabelGroup {
                        ConnectedUniversalLabel("Basic Label")
                        
                        ConnectedUniversalLabel("Label with Icon")
                            .withIcon("iphone")
                        
                        ConnectedUniversalLabel("Label with Value")
                            .withValue("Woah!")
                        
                        ConnectedUniversalLabel("Icon + Value")
                            .withValue("Woah!")
                            .withIcon("iphone")
                            .lastConnectedItem()
                    }
                    .padding(.horizontal)
                    .padding(.top, -8)
                    
                    // MARK: - Labels with Toggles
                    CenteredSectionHeader(title: "LABELS WITH TOGGLES")
                    
                    ConnectedLabelGroup {
                        ConnectedUniversalLabel("Basic Toggle")
                            .withToggle($isToggleOn)
                        
                        ConnectedUniversalLabel("Toggle with Icon")
                            .withToggle($isToggleOn)
                            .withIcon("iphone")
                            .lastConnectedItem()
                    }
                    .padding(.horizontal)
                    .padding(.top, -8)
                    
                    // MARK: - Labels with Text Inputs
                    CenteredSectionHeader(title: "LABELS WITH TEXT INPUTS")
                    
                    ConnectedLabelGroup {
                        ConnectedUniversalLabel("Text Input")
                            .withTextInput($textInput, placeholder: "Enter text")
                        
                        ConnectedUniversalLabel("Text Input with Icon")
                            .withTextInput($textInput, placeholder: "Enter text")
                            .withIcon("iphone")
                            .lastConnectedItem()
                    }
                    .padding(.horizontal)
                    .padding(.top, -8)
                    
                    // MARK: - Labels with Descriptions
                    CenteredSectionHeader(title: "LABELS WITH DESCRIPTIONS")
                    
                    ConnectedLabelGroup {
                        ConnectedUniversalLabel("With Description")
                            .withDescription("This is a description that can be multiple lines long and provides additional context about the label.")
                        
                        ConnectedUniversalLabel("Description + Icon")
                            .withDescription("This description includes an icon for better visual context.")
                            .withIcon("iphone")
                            .lastConnectedItem()
                    }
                    .padding(.horizontal)
                    .padding(.top, -8)
                    
                    // MARK: - Labels with Buttons
                    CenteredSectionHeader(title: "LABELS WITH BUTTONS")
                    
                    ConnectedLabelGroup {
                        ConnectedUniversalLabel("With Icon Button")
                            .withButton(.icon("plus"), action: {
                                ToastManager.shared.showToast.log("Tapped icon button")
                            })
                        
                        ConnectedUniversalLabel("With Text Button")
                            .withButton(.text("Go"), action: {
                                ToastManager.shared.showToast.log("Tapped text button")
                            })
                        
                        ConnectedUniversalLabel("Value with Button")
                            .withValue("42")
                            .withButton(.icon("arrow.right"), action: {
                                ToastManager.shared.showToast.log("Tapped value button")
                            })
                        
                        ConnectedUniversalLabel("Text Input with Button")
                            .withTextInput($textInput, placeholder: "Type here...")
                            .withButton(.icon("checkmark"), action: {
                                ToastManager.shared.showToast.log("Tapped text input button")
                            })
                            .lastConnectedItem()
                    }
                    .padding(.horizontal)
                    .padding(.top, -8)

                    // MARK: - Non-Connected Labels
                    CenteredSectionHeader(title: "NON-CONNECTED LABELS")
                    
                    VStack(spacing: 6) {
                        UniversalLabel("Basic Label")
                            .padding(.horizontal)
                        
                        UniversalLabel("Label with Icon")
                            .withIcon("iphone")
                            .padding(.horizontal)
                        
                        UniversalLabel("Label with Value")
                            .withValue("Woah!")
                            .padding(.horizontal)
                        
                        UniversalLabel("Icon + Value")
                            .withValue("Woah!")
                            .withIcon("iphone")
                            .padding(.horizontal)
                        
                        UniversalLabel("Basic Toggle")
                            .withToggle($isToggleOn)
                            .padding(.horizontal)
                        
                        UniversalLabel("Toggle with Icon")
                            .withToggle($isToggleOn)
                            .withIcon("iphone")
                            .padding(.horizontal)
                        
                        UniversalLabel("Text Input")
                            .withTextInput($textInput, placeholder: "Enter text")
                            .padding(.horizontal)
                        
                        UniversalLabel("Text Input with Icon")
                            .withTextInput($textInput, placeholder: "Enter text")
                            .withIcon("iphone")
                            .padding(.horizontal)
                        
                        UniversalLabel("With Description")
                            .withDescription("This is a description that can be multiple lines long and provides additional context about the label.")
                            .padding(.horizontal)
                        
                        UniversalLabel("Description + Icon")
                            .withDescription("This description includes an icon for better visual context.")
                            .withIcon("iphone")
                            .padding(.horizontal)
                        
                        UniversalLabel("With Icon Button")
                            .withButton(.icon("plus"), action: {
                                ToastManager.shared.showToast.log("Tapped icon button")
                            })
                            .padding(.horizontal)
                        
                        UniversalLabel("With Text Button")
                            .withButton(.text("Go"), action: {
                                ToastManager.shared.showToast.log("Tapped text button")
                            })
                            .padding(.horizontal)
                        
                        UniversalLabel("Value with Button")
                            .withValue("42")
                            .withButton(.icon("arrow.right"), action: {
                                ToastManager.shared.showToast.log("Tapped value button")
                            })
                            .padding(.horizontal)
                        
                        UniversalLabel("Text Input with Button")
                            .withTextInput($textInput, placeholder: "Type here...")
                            .withButton(.icon("checkmark"), action: {
                                ToastManager.shared.showToast.log("Tapped text input button")
                            })
                            .padding(.horizontal)
                    }
                    .padding(.top, -8)
                }
                .padding(.vertical, 20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("New UI")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.medium()
                        ToastManager.shared.showToast.log("Clicked Done (toolbar) in Button Styles")
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(themeAccent.accentColor)
                }
            }
        }
    }
}
