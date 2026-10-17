from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
w=Path(__file__).resolve().parent.parent;r=w/'user_source/hdl_source'
labels=['白平衡演示','模式：自动','模式：环境预设','模式：自定义','长按画面进入设置','回退','白平衡设置','自动白平衡','环境预设','手动白平衡','感光度','自动模式已启用','自动适应环境光','切换光源后稍候','选择光照环境','暖色灯光 3000K','日光 5500K','阴天 6500K','阴影 7500K','拖动滑条调节色温','2500K','10000K','感光度','减少','增加','恢复默认','触屏未连接','实时预览','','','每格 100K','实体按键同步可用','1倍','2倍','4倍','目标识别','开启','关闭','球体或方块','色彩偏移','归零','统计有效','等待稳定帧','B','A','G','M','','','','','','按键']
chars=sorted(set(''.join(labels)+'0123456789K增益 /.倍RBAGM'))
assert len(chars)<=128
ids={c:i for i,c in enumerate(chars)}
font=ImageFont.truetype('C:/Windows/Fonts/msyh.ttc',22)
data=[]
for c in chars:
    im=Image.new('L',(24,24));d=ImageDraw.Draw(im)
    box=d.textbbox((0,0),c,font=font)
    d.text(((24-(box[2]-box[0]))//2-box[0],(24-(box[3]-box[1]))//2-box[1]),c,font=font,fill=255)
    for y in range(32):
        value=0
        for x in range(24):value=(value<<1)|int(y<24 and im.getpixel((x,y))>=100)
        data.append(f'{value:06x}')
(r/'ui/wb_ui_font.hex').write_text('\n'.join(data)+'\n',encoding='ascii')
(r/'ui/wb_ui_font.v').write_text(f'''module wb_ui_font #(parameter FONT_FILE="../../../user_source/hdl_source/ui/wb_ui_font.hex")(
 input wire I_clk,input wire [11:0] I_addr,output reg [23:0] O_bits);
 (* ram_style="block" *) reg [23:0] font[0:{len(data)-1}];
 initial $readmemh(FONT_FILE,font);
 always @(posedge I_clk)O_bits<=font[I_addr];
endmodule
''',encoding='utf-8')
f='    function [6:0] glyph(input [5:0] text_id,input [5:0] pos);\n        begin\n            glyph=7\'d'+str(ids[' '])+';\n            case(text_id)\n'
for idx,label in enumerate(labels):
    if not label or idx==52:continue
    f+=f'            6\'d{idx}:case(pos)\n'
    for j,c in enumerate(label):f+=f"                6'd{j}:glyph=7'd{ids[c]};\n"
    f+='                default:;endcase\n'
f+='''            6'd28:case(pos)
                0:if(k_units>=100)glyph=DIGIT_1;
                1:glyph=digit_glyph((k_units/10)%10);
                2:glyph=digit_glyph(k_units%10);
                3,4:glyph=DIGIT_0;
                5:glyph=LETTER_K;
                default:;endcase
            6'd29:case(pos)
                0:glyph=digit_glyph(gain100/100);
                1:glyph=CHAR_DOT;
                2:glyph=digit_glyph((gain100/10)%10);
                3:glyph=digit_glyph(gain100%10);
                4:glyph=CHAR_BEI;
                default:;endcase
            6'd47,6'd48,6'd49:case(pos)
                0:glyph=(text_id==47)?CHAR_R:(text_id==48)?CHAR_G:CHAR_B;
                2:glyph=digit_glyph(((text_id==47)?tr100:(text_id==48)?tg100:tb100)/100);
                3:glyph=CHAR_DOT;
                4:glyph=digit_glyph((((text_id==47)?tr100:(text_id==48)?tg100:tb100)/10)%10);
                5:glyph=digit_glyph(((text_id==47)?tr100:(text_id==48)?tg100:tb100)%10);
                6:glyph=CHAR_BEI;
                default:;endcase
            6'd52:case(pos)
                0:glyph=CHAR_AN;1:glyph=CHAR_JIAN;
                3:glyph=active[33]?CHAR_G:CHAR_B;
                4:glyph=active[33]?CHAR_M:CHAR_A;
                default:;endcase
            6'd50:case(pos)
                0:glyph=ab<0?CHAR_B:CHAR_A;
                1:glyph=digit_glyph(ab<0?-ab:ab);
                default:;endcase
            6'd51:case(pos)
                0:glyph=gm<0?CHAR_M:CHAR_G;
                1:glyph=digit_glyph(gm<0?-gm:gm);
                default:;endcase
            default:;
            endcase
        end
    endfunction
'''
constants=''
for name,c in [('DIGIT_0','0'),('DIGIT_1','1'),('DIGIT_7','7'),('DIGIT_3','3'),('LETTER_K','K'),('CHAR_ZENG','增'),('CHAR_YI','益'),('CHAR_SLASH','/'),('CHAR_DOT','.'),('CHAR_BEI','倍'),('CHAR_R','R'),('CHAR_G','G'),('CHAR_B','B'),('CHAR_A','A'),('CHAR_M','M'),('CHAR_AN','按'),('CHAR_JIAN','键')]:constants+=f"    localparam {name}=7'd{ids[c]};\n"
constants+='    function [6:0] digit_glyph(input [3:0] n);begin case(n)\n'
for n in range(10):constants+=f"        4'd{n}:digit_glyph=7'd{ids[str(n)]};\n"
constants+=f"        default:digit_glyph=7'd{ids[' ']};endcase end endfunction\n"
template=(w/'tools/wb_ui_overlay.template.v').read_text(encoding='utf-8')
(r/'ui/wb_ui_overlay.v').write_text(template.replace('// GENERATED_GLYPHS',constants+f),encoding='utf-8')
print(f'Generated {len(chars)} glyphs, {len(data)*24} font bits; Kelvin LUT unchanged')
