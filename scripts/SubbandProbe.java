import java.util.Arrays;

import ucar.jpeg.jj2000.j2k.codestream.HeaderInfo;
import ucar.jpeg.jj2000.j2k.codestream.reader.BitstreamReaderAgent;
import ucar.jpeg.jj2000.j2k.codestream.reader.HeaderDecoder;
import ucar.jpeg.jj2000.j2k.decoder.Decoder;
import ucar.jpeg.jj2000.j2k.decoder.DecoderSpecs;
import ucar.jpeg.jj2000.j2k.entropy.decoder.DecLyrdCBlk;
import ucar.jpeg.jj2000.j2k.entropy.decoder.EntropyDecoder;
import ucar.jpeg.jj2000.j2k.fileformat.reader.FileFormatReader;
import ucar.jpeg.jj2000.j2k.io.BEBufferedRandomAccessFile;
import ucar.jpeg.jj2000.j2k.io.RandomAccessIO;
import ucar.jpeg.jj2000.j2k.util.ParameterList;
import ucar.jpeg.jj2000.j2k.wavelet.synthesis.SubbandSyn;

public class SubbandProbe {
    public static void main(String[] args) throws Exception {
        String path = args.length > 0 ? args[0] : "test_images/barras_rgb.jp2";
        RandomAccessIO input = new BEBufferedRandomAccessFile(path, "r");
        try {
            FileFormatReader ff = new FileFormatReader(input);
            ff.readFileFormat();
            if (ff.JP2FFUsed) {
                input.seek(ff.getFirstCodeStreamPos());
            }

            ParameterList defaults = new ParameterList();
            String[][] params = Decoder.getAllParameters();
            for (int i = params.length - 1; i >= 0; i--) {
                if (params[i][3] != null) {
                    defaults.put(params[i][0], params[i][3]);
                }
            }
            ParameterList pl = new ParameterList(defaults);
            pl.put("i", path);

            HeaderInfo info = new HeaderInfo();
            HeaderDecoder hd = new HeaderDecoder(input, pl, info);
            DecoderSpecs specs = hd.getDecoderSpecs();

            BitstreamReaderAgent reader = BitstreamReaderAgent.createInstance(
                input,
                hd,
                pl,
                specs,
                false,
                info
            );

            EntropyDecoder ent = hd.createEntropyDecoder(reader, pl);

            reader.setTile(0, 0);
            ent.setTile(0, 0);

            int tileIdx = reader.getTileIdx();
            for (int c = 0; c < reader.getNumComps(); c++) {
                System.out.println("=== Component " + c + " ===");
                SubbandSyn root = ent.getSynSubbandTree(tileIdx, c);
                traverse(root);
                dumpCodeBlocks(reader, tileIdx, c, root);
            }
        } finally {
            input.close();
        }
    }

    private static void traverse(SubbandSyn sb) {
        String numCb = sb.numCb == null ? "null" : sb.numCb.x + "x" + sb.numCb.y;
        System.out.printf(
            "node=%s res=%d band=%d level=%d w=%d h=%d nom=%dx%d numCb=%s%n",
            sb.isNode ? "Y" : "N",
            sb.resLvl,
            sb.sbandIdx,
            sb.level,
            sb.w,
            sb.h,
            sb.nomCBlkW,
            sb.nomCBlkH,
            numCb
        );
        if (sb.isNode) {
            traverse((SubbandSyn) sb.getLL());
            traverse((SubbandSyn) sb.getHL());
            traverse((SubbandSyn) sb.getLH());
            traverse((SubbandSyn) sb.getHH());
        }
    }

    private static void dumpCodeBlocks(BitstreamReaderAgent reader, int tileIdx, int component, SubbandSyn sb) {
        if (sb.isNode) {
            dumpCodeBlocks(reader, tileIdx, component, (SubbandSyn) sb.getLL());
            dumpCodeBlocks(reader, tileIdx, component, (SubbandSyn) sb.getHL());
            dumpCodeBlocks(reader, tileIdx, component, (SubbandSyn) sb.getLH());
            dumpCodeBlocks(reader, tileIdx, component, (SubbandSyn) sb.getHH());
            return;
        }

        if (sb.numCb == null || sb.numCb.x == 0 || sb.numCb.y == 0) {
            System.out.printf(
                "no code-blocks: t=%d c=%d res=%d band=%d numCb=%s%n",
                tileIdx,
                component,
                sb.resLvl,
                sb.sbandIdx,
                sb.numCb == null ? "null" : sb.numCb.x + "x" + sb.numCb.y
            );
            return;
        }

        for (int m = 0; m < sb.numCb.y; m++) {
            for (int n = 0; n < sb.numCb.x; n++) {
                DecLyrdCBlk block = reader.getCodeBlock(component, m, n, sb, 1, -1, null);
                System.out.printf(
                    "cblk t=%d c=%d res=%d band=%d m=%d n=%d dl=%d nl=%d ftpIdx=%d nTrunc=%d prog=%s skip=%d dataSample=%s ts=%s%n",
                    tileIdx,
                    component,
                    sb.resLvl,
                    sb.sbandIdx,
                    m,
                    n,
                    block.dl,
                    block.nl,
                    block.ftpIdx,
                    block.nTrunc,
                    block.prog,
                    block.skipMSBP,
                    summarizeBytes(block.data, block.dl),
                    block.tsLengths == null ? "null" : Arrays.toString(trim(block.tsLengths, block.nTrunc - block.ftpIdx))
                );
            }
        }
    }

    private static int[] trim(int[] values, int count) {
        if (values == null) {
            return null;
        }
        if (count <= 0 || count >= values.length) {
            return values;
        }
        int[] copy = new int[count];
        System.arraycopy(values, 0, copy, 0, count);
        return copy;
    }

    private static String summarizeBytes(byte[] data, int length) {
        if (data == null || length <= 0) {
            return "[]";
        }
        int count = Math.min(length, 16);
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (int i = 0; i < count; i++) {
            if (i > 0) {
                sb.append(' ');
            }
            sb.append(String.format("%02X", data[i] & 0xFF));
        }
        if (length > count) {
            sb.append(" ...");
        }
        sb.append(']');
        return sb.toString();
    }
}
