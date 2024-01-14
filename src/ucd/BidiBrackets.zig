pub const Bracket = struct {
    pair: u32,
    type: BracketType,
    mapping: ?u32,
};
pub const BracketType = enum {
    opening,
    closing,
};
pub fn get(c: u32) ?Bracket {
    return switch (c) {
        '\u{0028}' => Bracket{
            .pair = '\u{0029}',
            .type = .opening,
            .mapping = null,
        },
        '\u{0029}' => Bracket{
            .pair = '\u{0028}',
            .type = .closing,
            .mapping = null,
        },
        '\u{005B}' => Bracket{
            .pair = '\u{005D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{005D}' => Bracket{
            .pair = '\u{005B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{007B}' => Bracket{
            .pair = '\u{007D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{007D}' => Bracket{
            .pair = '\u{007B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{0F3A}' => Bracket{
            .pair = '\u{0F3B}',
            .type = .opening,
            .mapping = null,
        },
        '\u{0F3B}' => Bracket{
            .pair = '\u{0F3A}',
            .type = .closing,
            .mapping = null,
        },
        '\u{0F3C}' => Bracket{
            .pair = '\u{0F3D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{0F3D}' => Bracket{
            .pair = '\u{0F3C}',
            .type = .closing,
            .mapping = null,
        },
        '\u{169B}' => Bracket{
            .pair = '\u{169C}',
            .type = .opening,
            .mapping = null,
        },
        '\u{169C}' => Bracket{
            .pair = '\u{169B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2045}' => Bracket{
            .pair = '\u{2046}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2046}' => Bracket{
            .pair = '\u{2045}',
            .type = .closing,
            .mapping = null,
        },
        '\u{207D}' => Bracket{
            .pair = '\u{207E}',
            .type = .opening,
            .mapping = null,
        },
        '\u{207E}' => Bracket{
            .pair = '\u{207D}',
            .type = .closing,
            .mapping = null,
        },
        '\u{208D}' => Bracket{
            .pair = '\u{208E}',
            .type = .opening,
            .mapping = null,
        },
        '\u{208E}' => Bracket{
            .pair = '\u{208D}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2308}' => Bracket{
            .pair = '\u{2309}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2309}' => Bracket{
            .pair = '\u{2308}',
            .type = .closing,
            .mapping = null,
        },
        '\u{230A}' => Bracket{
            .pair = '\u{230B}',
            .type = .opening,
            .mapping = null,
        },
        '\u{230B}' => Bracket{
            .pair = '\u{230A}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2329}' => Bracket{
            .pair = '\u{232A}',
            .type = .opening,
            .mapping = '\u{3008}',
        },
        '\u{232A}' => Bracket{
            .pair = '\u{2329}',
            .type = .closing,
            .mapping = '\u{3009}',
        },
        '\u{2768}' => Bracket{
            .pair = '\u{2769}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2769}' => Bracket{
            .pair = '\u{2768}',
            .type = .closing,
            .mapping = null,
        },
        '\u{276A}' => Bracket{
            .pair = '\u{276B}',
            .type = .opening,
            .mapping = null,
        },
        '\u{276B}' => Bracket{
            .pair = '\u{276A}',
            .type = .closing,
            .mapping = null,
        },
        '\u{276C}' => Bracket{
            .pair = '\u{276D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{276D}' => Bracket{
            .pair = '\u{276C}',
            .type = .closing,
            .mapping = null,
        },
        '\u{276E}' => Bracket{
            .pair = '\u{276F}',
            .type = .opening,
            .mapping = null,
        },
        '\u{276F}' => Bracket{
            .pair = '\u{276E}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2770}' => Bracket{
            .pair = '\u{2771}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2771}' => Bracket{
            .pair = '\u{2770}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2772}' => Bracket{
            .pair = '\u{2773}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2773}' => Bracket{
            .pair = '\u{2772}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2774}' => Bracket{
            .pair = '\u{2775}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2775}' => Bracket{
            .pair = '\u{2774}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27C5}' => Bracket{
            .pair = '\u{27C6}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27C6}' => Bracket{
            .pair = '\u{27C5}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27E6}' => Bracket{
            .pair = '\u{27E7}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27E7}' => Bracket{
            .pair = '\u{27E6}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27E8}' => Bracket{
            .pair = '\u{27E9}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27E9}' => Bracket{
            .pair = '\u{27E8}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27EA}' => Bracket{
            .pair = '\u{27EB}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27EB}' => Bracket{
            .pair = '\u{27EA}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27EC}' => Bracket{
            .pair = '\u{27ED}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27ED}' => Bracket{
            .pair = '\u{27EC}',
            .type = .closing,
            .mapping = null,
        },
        '\u{27EE}' => Bracket{
            .pair = '\u{27EF}',
            .type = .opening,
            .mapping = null,
        },
        '\u{27EF}' => Bracket{
            .pair = '\u{27EE}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2983}' => Bracket{
            .pair = '\u{2984}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2984}' => Bracket{
            .pair = '\u{2983}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2985}' => Bracket{
            .pair = '\u{2986}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2986}' => Bracket{
            .pair = '\u{2985}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2987}' => Bracket{
            .pair = '\u{2988}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2988}' => Bracket{
            .pair = '\u{2987}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2989}' => Bracket{
            .pair = '\u{298A}',
            .type = .opening,
            .mapping = null,
        },
        '\u{298A}' => Bracket{
            .pair = '\u{2989}',
            .type = .closing,
            .mapping = null,
        },
        '\u{298B}' => Bracket{
            .pair = '\u{298C}',
            .type = .opening,
            .mapping = null,
        },
        '\u{298C}' => Bracket{
            .pair = '\u{298B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{298D}' => Bracket{
            .pair = '\u{2990}',
            .type = .opening,
            .mapping = null,
        },
        '\u{298E}' => Bracket{
            .pair = '\u{298F}',
            .type = .closing,
            .mapping = null,
        },
        '\u{298F}' => Bracket{
            .pair = '\u{298E}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2990}' => Bracket{
            .pair = '\u{298D}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2991}' => Bracket{
            .pair = '\u{2992}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2992}' => Bracket{
            .pair = '\u{2991}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2993}' => Bracket{
            .pair = '\u{2994}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2994}' => Bracket{
            .pair = '\u{2993}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2995}' => Bracket{
            .pair = '\u{2996}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2996}' => Bracket{
            .pair = '\u{2995}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2997}' => Bracket{
            .pair = '\u{2998}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2998}' => Bracket{
            .pair = '\u{2997}',
            .type = .closing,
            .mapping = null,
        },
        '\u{29D8}' => Bracket{
            .pair = '\u{29D9}',
            .type = .opening,
            .mapping = null,
        },
        '\u{29D9}' => Bracket{
            .pair = '\u{29D8}',
            .type = .closing,
            .mapping = null,
        },
        '\u{29DA}' => Bracket{
            .pair = '\u{29DB}',
            .type = .opening,
            .mapping = null,
        },
        '\u{29DB}' => Bracket{
            .pair = '\u{29DA}',
            .type = .closing,
            .mapping = null,
        },
        '\u{29FC}' => Bracket{
            .pair = '\u{29FD}',
            .type = .opening,
            .mapping = null,
        },
        '\u{29FD}' => Bracket{
            .pair = '\u{29FC}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E22}' => Bracket{
            .pair = '\u{2E23}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E23}' => Bracket{
            .pair = '\u{2E22}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E24}' => Bracket{
            .pair = '\u{2E25}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E25}' => Bracket{
            .pair = '\u{2E24}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E26}' => Bracket{
            .pair = '\u{2E27}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E27}' => Bracket{
            .pair = '\u{2E26}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E28}' => Bracket{
            .pair = '\u{2E29}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E29}' => Bracket{
            .pair = '\u{2E28}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E55}' => Bracket{
            .pair = '\u{2E56}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E56}' => Bracket{
            .pair = '\u{2E55}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E57}' => Bracket{
            .pair = '\u{2E58}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E58}' => Bracket{
            .pair = '\u{2E57}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E59}' => Bracket{
            .pair = '\u{2E5A}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E5A}' => Bracket{
            .pair = '\u{2E59}',
            .type = .closing,
            .mapping = null,
        },
        '\u{2E5B}' => Bracket{
            .pair = '\u{2E5C}',
            .type = .opening,
            .mapping = null,
        },
        '\u{2E5C}' => Bracket{
            .pair = '\u{2E5B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{3008}' => Bracket{
            .pair = '\u{3009}',
            .type = .opening,
            .mapping = '\u{2329}',
        },
        '\u{3009}' => Bracket{
            .pair = '\u{3008}',
            .type = .closing,
            .mapping = '\u{232A}',
        },
        '\u{300A}' => Bracket{
            .pair = '\u{300B}',
            .type = .opening,
            .mapping = null,
        },
        '\u{300B}' => Bracket{
            .pair = '\u{300A}',
            .type = .closing,
            .mapping = null,
        },
        '\u{300C}' => Bracket{
            .pair = '\u{300D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{300D}' => Bracket{
            .pair = '\u{300C}',
            .type = .closing,
            .mapping = null,
        },
        '\u{300E}' => Bracket{
            .pair = '\u{300F}',
            .type = .opening,
            .mapping = null,
        },
        '\u{300F}' => Bracket{
            .pair = '\u{300E}',
            .type = .closing,
            .mapping = null,
        },
        '\u{3010}' => Bracket{
            .pair = '\u{3011}',
            .type = .opening,
            .mapping = null,
        },
        '\u{3011}' => Bracket{
            .pair = '\u{3010}',
            .type = .closing,
            .mapping = null,
        },
        '\u{3014}' => Bracket{
            .pair = '\u{3015}',
            .type = .opening,
            .mapping = null,
        },
        '\u{3015}' => Bracket{
            .pair = '\u{3014}',
            .type = .closing,
            .mapping = null,
        },
        '\u{3016}' => Bracket{
            .pair = '\u{3017}',
            .type = .opening,
            .mapping = null,
        },
        '\u{3017}' => Bracket{
            .pair = '\u{3016}',
            .type = .closing,
            .mapping = null,
        },
        '\u{3018}' => Bracket{
            .pair = '\u{3019}',
            .type = .opening,
            .mapping = null,
        },
        '\u{3019}' => Bracket{
            .pair = '\u{3018}',
            .type = .closing,
            .mapping = null,
        },
        '\u{301A}' => Bracket{
            .pair = '\u{301B}',
            .type = .opening,
            .mapping = null,
        },
        '\u{301B}' => Bracket{
            .pair = '\u{301A}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FE59}' => Bracket{
            .pair = '\u{FE5A}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FE5A}' => Bracket{
            .pair = '\u{FE59}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FE5B}' => Bracket{
            .pair = '\u{FE5C}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FE5C}' => Bracket{
            .pair = '\u{FE5B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FE5D}' => Bracket{
            .pair = '\u{FE5E}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FE5E}' => Bracket{
            .pair = '\u{FE5D}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FF08}' => Bracket{
            .pair = '\u{FF09}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FF09}' => Bracket{
            .pair = '\u{FF08}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FF3B}' => Bracket{
            .pair = '\u{FF3D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FF3D}' => Bracket{
            .pair = '\u{FF3B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FF5B}' => Bracket{
            .pair = '\u{FF5D}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FF5D}' => Bracket{
            .pair = '\u{FF5B}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FF5F}' => Bracket{
            .pair = '\u{FF60}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FF60}' => Bracket{
            .pair = '\u{FF5F}',
            .type = .closing,
            .mapping = null,
        },
        '\u{FF62}' => Bracket{
            .pair = '\u{FF63}',
            .type = .opening,
            .mapping = null,
        },
        '\u{FF63}' => Bracket{
            .pair = '\u{FF62}',
            .type = .closing,
            .mapping = null,
        },
        else => null,
    };
}