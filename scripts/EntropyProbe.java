import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;

import ucar.jpeg.jj2000.j2k.codestream.HeaderInfo;
import ucar.jpeg.jj2000.j2k.codestream.reader.BitstreamReaderAgent;
import ucar.jpeg.jj2000.j2k.codestream.reader.HeaderDecoder;
import ucar.jpeg.jj2000.j2k.decoder.Decoder;
import ucar.jpeg.jj2000.j2k.decoder.DecoderSpecs;
import ucar.jpeg.jj2000.j2k.entropy.decoder.EntropyDecoder;
import ucar.jpeg.jj2000.j2k.fileformat.reader.FileFormatReader;
import ucar.jpeg.jj2000.j2k.image.DataBlkInt;
import ucar.jpeg.jj2000.j2k.io.BEBufferedRandomAccessFile;
import ucar.jpeg.jj2000.j2k.io.RandomAccessIO;
import ucar.jpeg.jj2000.j2k.util.ParameterList;
import ucar.jpeg.jj2000.j2k.wavelet.Subband;
import ucar.jpeg.jj2000.j2k.wavelet.synthesis.SubbandSyn;

public class EntropyProbe {
    public static void main(String[] args) throws Exception {
        String path = args.length > 0 ? args[0] : "test_images/barras_rgb.jp2";
        String output = args.length > 1 ? args[1] : "build/java_entropy_dump.json";
        String filterArg = args.length > 2 ? args[2] : null;
        List<String> filters = parseFilters(filterArg);
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

            int tile = 0;
            reader.setTile(tile, 0);
            ent.setTile(tile, 0);
            List<String> blockEntries = new ArrayList<>();
            int numComps = reader.getNumComps();
            for (int component = 0; component < numComps; component++) {
                SubbandSyn root = ent.getSynSubbandTree(reader.getTileIdx(), component);
                collectBlocks(ent, component, root, filters, blockEntries);
            }

            writeJson(output, path, tile, blockEntries);
        } finally {
            input.close();
        }
    }

    private static List<String> parseFilters(String filterArg) {
        if (filterArg == null || filterArg.isEmpty()) {
            return null;
        }
        String[] parts = filterArg.split(",");
        List<String> filters = new ArrayList<>();
        for (String part : parts) {
            String trimmed = part.trim();
            if (!trimmed.isEmpty()) {
                filters.add(trimmed);
            }
        }
        return filters.isEmpty() ? null : filters;
    }

    private static boolean matchesFilter(int component, int res, int band, List<String> filters) {
        if (filters == null) {
            return true;
        }
        String key = component + ":" + res + ":" + band;
        return filters.contains(key);
    }

    private static void collectBlocks(
        EntropyDecoder ent,
        int component,
        SubbandSyn sb,
        List<String> filters,
        List<String> entries
    ) {
        if (sb.isNode) {
            collectBlocks(ent, component, (SubbandSyn) sb.getLL(), filters, entries);
            collectBlocks(ent, component, (SubbandSyn) sb.getHL(), filters, entries);
            collectBlocks(ent, component, (SubbandSyn) sb.getLH(), filters, entries);
            collectBlocks(ent, component, (SubbandSyn) sb.getHH(), filters, entries);
            return;
        }

        if (sb.numCb == null || sb.numCb.x == 0 || sb.numCb.y == 0) {
            return;
        }

        if (!matchesFilter(component, sb.resLvl, sb.sbandIdx, filters)) {
            return;
        }

        DataBlkInt out = new DataBlkInt();
        for (int m = 0; m < sb.numCb.y; m++) {
            for (int n = 0; n < sb.numCb.x; n++) {
                DataBlkInt result = (DataBlkInt) ent.getCodeBlock(component, m, n, sb, out);
                int[] coeffs = extractCoefficients(result);
                entries.add(formatEntry(component, sb.resLvl, sb.sbandIdx, m, n, result, coeffs));
            }
        }
    }

    private static int[] extractCoefficients(DataBlkInt blk) {
        int w = blk.w;
        int h = blk.h;
        int scanw = blk.scanw;
        int offset = blk.offset;
        int[] data = blk.getDataInt();
        if (data == null) {
            return new int[0];
        }
        int[] copy = new int[w * h];
        int idx = 0;
        for (int y = 0; y < h; y++) {
            System.arraycopy(data, offset + y * scanw, copy, idx, w);
            idx += w;
        }
        return copy;
    }

    private static String formatEntry(int component, int res, int band, int m, int n, DataBlkInt blk, int[] coeffs) {
        StringBuilder sb = new StringBuilder();
        sb.append('{')
          .append("\"component\":").append(component).append(',')
          .append("\"res\":").append(res).append(',')
          .append("\"band\":").append(band).append(',')
          .append("\"m\":").append(m).append(',')
          .append("\"n\":").append(n).append(',')
          .append("\"ulx\":").append(blk.ulx).append(',')
          .append("\"uly\":").append(blk.uly).append(',')
          .append("\"w\":").append(blk.w).append(',')
          .append("\"h\":").append(blk.h).append(',')
                    .append("\"coeffs\":").append(intArrayToJson(coeffs))
          .append('}');
        return sb.toString();
    }

    private static String intArrayToJson(int[] values) {
        StringBuilder sb = new StringBuilder();
        sb.append('[');
        for (int i = 0; i < values.length; i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(values[i]);
        }
        sb.append(']');
        return sb.toString();
    }

    private static void writeJson(String output, String imagePath, int tile, List<String> blocks) throws IOException {
        Path outPath = Paths.get(output);
        Path parent = outPath.getParent();
        if (parent != null) {
            Files.createDirectories(parent);
        }
        StringBuilder sb = new StringBuilder();
        sb.append('{')
          .append("\"image\":\"").append(imagePath.replace("\\", "\\\\")).append("\",")
          .append("\"tile\":").append(tile).append(',')
          .append("\"blocks\":[");
        for (int i = 0; i < blocks.size(); i++) {
            if (i > 0) {
                sb.append(',');
            }
            sb.append(blocks.get(i));
        }
        sb.append(']').append('}');
        Files.write(outPath, sb.toString().getBytes(StandardCharsets.UTF_8));
        System.out.println("Wrote " + blocks.size() + " blocks to " + outPath);
    }
}
