import java.util.Arrays;
import ucar.jpeg.jj2000.j2k.entropy.decoder.ByteInputBuffer;
import ucar.jpeg.jj2000.j2k.entropy.decoder.MQDecoder;

public class TestMq {
    private static void dump(byte[] data, int symbols) {
        ByteInputBuffer buffer = new ByteInputBuffer(data);
        int[] init = new int[19];
        MQDecoder decoder = new MQDecoder(buffer, 19, init);
        decoder.resetCtxts();
        int[] out = new int[symbols];
        for (int i = 0; i < symbols; i++) {
            out[i] = decoder.decodeSymbol(0);
        }
        System.out.println(Arrays.toString(out));
    }

    public static void main(String[] args) {
        dump(new byte[] {(byte)0x84, (byte)0x00}, 10);
        dump(new byte[] {(byte)0xAA, (byte)0x55, (byte)0xAA}, 15);
        dump(new byte[] {(byte)0x84, (byte)0x00, (byte)0x00, (byte)0x00}, 20);
    }
}
