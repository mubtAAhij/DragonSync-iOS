

import zmq
import json
import threading
import time

class ZMQDecoder:
    def __init__(self, zmq_host="0.0.0.0", zmq_port=4224):
        self.zmq_host = zmq_host
        self.zmq_port = zmq_port
        self.context = zmq.Context()
        self.publisher = self.context.socket(zmq.PUB)
        
    def start(self):
        zmq_address = f"tcp://{self.zmq_host}:{self.zmq_port}"
        self.publisher.bind(zmq_address)
        print(f"ZMQDecoder started at {zmq_address}")
        
        # Continuously publish dummy data
        while True:
            # Simulate sending messages on specific topics
            topics = ["AUX_ADV_IND", "DroneID"]
            for topic in topics:
                message = {
                    "topic": topic,
                    "data": f"Dummy data for {topic}",
                    "timestamp": time.time()
                }
                self.publisher.send_string(f"{topic} {json.dumps(message)}")
                print(f"Published: {message}")
                time.sleep(5)  # Adjust the frequency of message publication as needed
                
                
class ZMQMonitor:
    def __init__(self, zmq_decoder_host="127.0.0.1", zmq_decoder_port=4224):
        self.zmq_decoder_host = zmq_decoder_host
        self.zmq_decoder_port = zmq_decoder_port
        self.context = zmq.Context()
        self.subscriber = self.context.socket(zmq.SUB)
        
    def connect(self):
        zmq_address = f"tcp://{self.zmq_decoder_host}:{self.zmq_decoder_port}"
        self.subscriber.connect(zmq_address)
        # Subscribe to all topics
        self.subscriber.setsockopt_string(zmq.SUBSCRIBE, "")
        print(f"ZMQMonitor connected to {zmq_address}")
        
    def listen(self):
        print("ZMQMonitor listening for messages...")
        while True:
            try:
                # Receive topic and message
                raw_message = self.subscriber.recv_string()
                topic, message = raw_message.split(" ", 1)
                print(f"Received on topic '{topic}': {message}")
                
                # Decode JSON message
                data = json.loads(message)
                self.process_message(topic, data)
                
            except KeyboardInterrupt:
                print("ZMQMonitor shutting down...")
                break
            except Exception as e:
                print(f"Error processing message: {e}")
                
    def process_message(self, topic, data):
        # Handle received messages (forward, store, etc.)
        print(f"Processed message from topic '{topic}': {data}")
        
        
if __name__ == "__main__":
    # Start ZMQDecoder in a separate thread
    decoder = ZMQDecoder(zmq_host="0.0.0.0", zmq_port=4224)
    decoder_thread = threading.Thread(target=decoder.start, daemon=True)
    decoder_thread.start()
    
    # Start ZMQMonitor in the main thread
    monitor = ZMQMonitor(zmq_decoder_host="127.0.0.1", zmq_decoder_port=4224)
    monitor.connect()
    monitor.listen()
    