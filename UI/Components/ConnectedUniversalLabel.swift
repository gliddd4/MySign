// ... existing code ...
    var body: some View {
        HStack {
            Text(title)
// ... existing code ...
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 56)
        .background(Color.clear)
    }
}

// ... existing code ...
// ... existing code ...
    var body: some View {
        HStack {
            Image(systemName: iconName)
// ... existing code ...
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal)
        .frame(height: 56)
        .background(Color.clear)
    }
}

extension ConnectedUniversalLabelWithIcon {
// ... existing code ...
// ... existing code ...
        Text(value)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
            .lineLimit(1)
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

extension ConnectedUniversalLabelWithValue {
// ... existing code ...
// ... existing code ...
        Text(value)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
            .lineLimit(1)
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

extension ConnectedUniversalLabelWithIconAndValue {
// ... existing code ...
// ... existing code ...
    HStack {
        Text(title)
            .font(.system(size: 14, weight: .semibold))
// ... existing code ...
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(WideToggle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

extension ConnectedUniversalLabelWithToggle {
// ... existing code ...
// ... existing code ...
        Toggle("", isOn: $isOn)
            .labelsHidden()
            .toggleStyle(WideToggle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Text Input
// ... existing code ...
                TextField("", text: $text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .textFieldStyle(PlainTextFieldStyle())
            }
        }
        .padding(.horizontal)
        .frame(height: 56)
        .background(Color.clear)
    }
}

extension ConnectedUniversalLabelWithTextInput {
// ... existing code ...
// ... existing code ...
                TextField("", text: $text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
                    .textFieldStyle(PlainTextFieldStyle())
            }
        }
        .padding(.horizontal)
        .frame(height: 56)
        .background(Color.clear)
    }
}

extension ConnectedUniversalLabelWithIconAndTextInput {
// ... existing code ...
// ... existing code ...
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            Text(title)
// ... existing code ...
            .foregroundColor(.gray)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
    }
    .padding(.horizontal)
    .padding(.vertical, 20)
    .background(Color.clear)
}

extension ConnectedUniversalLabelWithDescription {
// ... existing code ...
// ... existing code ...
        Text(description)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.gray)
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
    }
    .padding(.horizontal)
    .padding(.vertical, 20)
    .background(Color.clear)
}

extension ConnectedUniversalLabelWithIconAndDescription {
// ... existing code ...
// ... existing code ...
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Icon and Button
// ... existing code ...
// ... existing code ...
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Value and Button
// ... existing code ...
// ... existing code ...
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Icon, Value and Button
// ... existing code ...
// ... existing code ...
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Text Input and Button
// ... existing code ...
// ... existing code ...
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}

// MARK: - Connected Label with Description and Button
// ... existing code ...
// ... existing code ...
    Text(description)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.gray)
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
    }
    .padding(.horizontal)
    .padding(.vertical, 20)
    .background(Color.clear)
}

// MARK: - Connected Label with Icon, Description and Button
// ... existing code ...
// ... existing code ...
    Text(description)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.gray)
        .multilineTextAlignment(.leading)
        .lineLimit(nil)
    }
    .padding(.horizontal)
    .padding(.vertical, 20)
    .background(Color.clear)
}

// MARK: - Connected Label with Icon and Text Input and Button
// ... existing code ...
// ... existing code ...
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal)
    .frame(height: 56)
    .background(Color.clear)
}